#!/usr/bin/env python3
"""sesiones.py: guarda en el OS las sesiones de Claude Code del motor.

Para mejorar el flujo, la casa lee cómo trabaja el motor en manos de cada
persona. Cada sesión del motor (la que corre en ~/videos o en una carpeta con
models/pieza.json) sube su transcript al OS con la llave de la marca, solo lo
nuevo cada vez. La persona lo sabe: el instalador lo dice y cada sesión lo
avisa una vez en pantalla.

  sesiones.py instalar   pone el hook en ~/.claude/settings.json (Stop y
                         SessionEnd) si una llave de la máquina es de una
                         persona del equipo que entrena formatos (lo decide
                         el OS), y sube una vez las sesiones del motor que ya
                         estén en la máquina. Sin esa llave lo quita.
                         Idempotente; lo corre pull-engine.sh.
  sesiones.py hook       lo llama Claude Code al final de cada turno y al
                         cerrar. Lee el evento por stdin, lanza la subida
                         aparte y sale en el acto: nunca frena la sesión.
  sesiones.py subir <transcript.jsonl> [--cwd carpeta] [--fin]
                         sube lo nuevo de un transcript (lo usa el hook).
  sesiones.py todas      sube todas las sesiones del motor de la máquina.

Solo usa la librería estándar de python3. Nada de lo que falle aquí corta
una sesión: el hook siempre sale con 0 y los errores van a
~/.ia-nomads/sesiones/registro.log.
"""
import fcntl
import glob
import gzip
import hashlib
import json
import os
import platform
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from collections import Counter

HOME = os.path.expanduser("~")
VIDEOS = os.path.join(HOME, "videos")
CONFIG = os.environ.get("ENGINE_CONFIG") or os.path.join(HOME, ".ia-nomads", "config")
ESTADO = os.path.join(HOME, ".ia-nomads", "sesiones")
REGISTRO = os.path.join(ESTADO, "registro.log")
SETTINGS = os.path.join(HOME, ".claude", "settings.json")
PROYECTOS = os.path.join(HOME, ".claude", "projects")
PARTE = 16 * 1024 * 1024
AVISO = ("Esta sesión del motor de video queda guardada en el OS de IA Nomads "
         "para mejorar el sistema.")
UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def log(msg):
    try:
        os.makedirs(ESTADO, exist_ok=True)
        if os.path.exists(REGISTRO) and os.path.getsize(REGISTRO) > 512 * 1024:
            os.replace(REGISTRO, REGISTRO + ".1")
        with open(REGISTRO, "a") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + msg + "\n")
    except Exception:
        pass


# ── ¿Es una sesión del motor? ──

def pieza_en(carpeta):
    """models/pieza.json de esta carpeta o de una superior dentro de ~/videos."""
    if not carpeta:
        return None
    d = os.path.realpath(carpeta)
    p = os.path.join(d, "models", "pieza.json")
    if os.path.isfile(p):
        return p
    tope = os.path.realpath(VIDEOS)
    while d.startswith(tope + os.sep):
        d = os.path.dirname(d)
        p = os.path.join(d, "models", "pieza.json")
        if os.path.isfile(p):
            return p
    return None


def es_del_motor(cwd):
    if not cwd:
        return False
    real = os.path.realpath(cwd)
    tope = os.path.realpath(VIDEOS)
    return real == tope or real.startswith(tope + os.sep) or bool(pieza_en(cwd))


# ── Llave ──

def leer_config():
    cfg = {}
    try:
        with open(CONFIG) as f:
            for linea in f:
                m = re.match(r"^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$", linea)
                if m:
                    cfg[m.group(1)] = m.group(2).strip("\"'")
    except OSError:
        pass
    return cfg


def nombre_llave(marca):
    return "ENGINE_SECRET_" + re.sub(r"[^A-Z0-9]", "_", marca.upper())


def elegir_llave(cfg, marca, texto):
    """La marca de la pieza manda; si no hay pieza, la marca que la sesión
    nombró con --client; si la máquina tiene una sola llave, esa. Nunca se
    adivina entre varias: sin marca clara la sesión espera al próximo turno."""
    if marca and cfg.get(nombre_llave(marca)):
        return cfg[nombre_llave(marca)], marca
    nombradas = Counter(m.lower() for m in re.findall(r"--client[ =]+([A-Za-z0-9_-]+)", texto))
    for m, _ in nombradas.most_common():
        if cfg.get(nombre_llave(m)):
            return cfg[nombre_llave(m)], m
    llaves = {k: v for k, v in cfg.items() if k.startswith("ENGINE_SECRET") and v}
    if len(set(llaves.values())) == 1:
        k, v = next(iter(llaves.items()))
        return v, (k[len("ENGINE_SECRET_"):].lower() if k != "ENGINE_SECRET" else None)
    return None, None


# ── Lectura del transcript ──

def resumen(texto, cwd, fin):
    """Lo que la lista del OS muestra, sacado del .jsonl."""
    inicio = ultimo = version = titulo = primer = None
    turnos = herramientas = 0
    for linea in texto.splitlines():
        try:
            o = json.loads(linea)
        except ValueError:
            continue
        ts = o.get("timestamp")
        if ts:
            inicio = inicio or ts
            ultimo = ts
        version = o.get("version") or version
        cwd = cwd or o.get("cwd")
        t = o.get("type")
        if t == "custom-title" and o.get("customTitle"):
            titulo = o["customTitle"]
        elif t == "ai-title" and o.get("aiTitle") and not titulo:
            titulo = o["aiTitle"]
        msg = o.get("message") if isinstance(o.get("message"), dict) else {}
        cont = msg.get("content")
        if t == "assistant" and isinstance(cont, list):
            herramientas += sum(1 for b in cont if isinstance(b, dict) and b.get("type") == "tool_use")
        if t == "user" and not o.get("isMeta") and not o.get("isSidechain"):
            txt = None
            if isinstance(cont, str):
                txt = cont
            elif isinstance(cont, list) and not any(isinstance(b, dict) and b.get("type") == "tool_result" for b in cont):
                txt = " ".join(b.get("text", "") for b in cont if isinstance(b, dict) and b.get("type") == "text")
            if txt and txt.strip() and not txt.lstrip().startswith("<"):
                turnos += 1
                primer = primer or txt.strip()
    return {
        "inicio": inicio, "fin": ultimo, "version": version, "cwd": cwd,
        "titulo": (titulo or primer or "")[:200] or None,
        "turnos": turnos, "herramientas": herramientas, "terminada": bool(fin),
    }


def buscar_pieza(cwd, texto):
    p = pieza_en(cwd)
    if not p:
        # La sesión puede abrirse en ~/videos y trabajar en una subcarpeta:
        # la pieza es la carpeta de ~/videos que más nombra.
        for nombre, _ in Counter(re.findall(r"/videos/([A-Za-z0-9._-]+)", texto)).most_common(5):
            cand = os.path.join(VIDEOS, nombre, "models", "pieza.json")
            if os.path.isfile(cand):
                p = cand
                break
    if not p:
        return None, {}
    try:
        with open(p) as f:
            return os.path.basename(os.path.dirname(os.path.dirname(p))), json.load(f)
    except (OSError, ValueError):
        return None, {}


# ── Red ──

def llamar(gateway, llave, cuerpo, timeout=60):
    req = urllib.request.Request(
        gateway.rstrip("/") + "/api/video-editor",
        data=json.dumps(cuerpo).encode(),
        method="POST",
        headers={"content-type": "application/json", "x-engine-secret": llave},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read() or b"{}")
        except ValueError:
            return e.code, {}


def poner(url, datos):
    req = urllib.request.Request(url, data=datos, method="PUT",
                                 headers={"content-type": "application/gzip"})
    with urllib.request.urlopen(req, timeout=600) as r:
        r.read()


# ── Subir ──

def maquina():
    sistema = platform.system().lower()
    if sistema == "linux":
        try:
            with open("/proc/version") as f:
                if "microsoft" in f.read().lower():
                    sistema = "wsl"
        except OSError:
            pass
    elif sistema == "darwin":
        sistema = "mac"
    return f"{platform.node()} ({sistema})"


def subir(ruta, fin=False, cwd=None):
    sid = os.path.splitext(os.path.basename(ruta))[0].lower()
    if not UUID.match(sid):
        return
    os.makedirs(ESTADO, exist_ok=True)
    # Un solo subidor por sesión. Si ya hay uno, se le deja dicho que hubo
    # un turno más y él vuelve a mirar al terminar.
    otra = os.path.join(ESTADO, sid + ".otra")
    candado = open(os.path.join(ESTADO, sid + ".lock"), "w")
    try:
        fcntl.flock(candado, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        with open(otra, "a") as f:
            f.write("fin" if fin else ".")
        return
    try:
        for _ in range(5):
            _subir_una_vez(ruta, sid, fin, cwd)
            if not os.path.exists(otra):
                break
            with open(otra) as f:
                fin = fin or "fin" in f.read()
            os.remove(otra)
    finally:
        candado.close()


def _subir_una_vez(ruta, sid, fin, cwd):
    with open(ruta, "rb") as f:
        datos = f.read()
    # Solo líneas completas: Claude puede estar escribiendo la última.
    datos = datos[:datos.rfind(b"\n") + 1]
    if not datos:
        return
    texto = datos.decode("utf-8", "replace")
    pieza, pj = buscar_pieza(cwd, texto)
    cfg = leer_config()
    llave, marca_llave = elegir_llave(cfg, pj.get("cliente") or pj.get("marca"), texto)
    if not llave:
        log(f"{sid}: sin llave clara para la marca, queda para el próximo turno")
        return
    gateway = os.environ.get("ENGINE_GATEWAY_URL") or cfg.get("ENGINE_GATEWAY_URL") or "https://app.ianomads.com"

    archivo_estado = os.path.join(ESTADO, sid + ".json")
    try:
        with open(archivo_estado) as f:
            estado = json.load(f)
    except (OSError, ValueError):
        estado = {}
    desde = 0
    hechos = int(estado.get("bytes") or 0)
    if 0 < hechos <= len(datos) and hashlib.md5(datos[:hechos]).hexdigest() == estado.get("md5"):
        desde = hechos
    if desde == len(datos) and (not fin or estado.get("terminada")):
        return

    meta = resumen(texto, cwd, fin)
    meta.update({
        "maquina": maquina(),
        "pieza": pieza,
        "post_id": pj.get("social_post_id") or pj.get("post_id"),
        "marca": pj.get("marca") or marca_llave,
    })

    def guardar(n):
        with open(archivo_estado, "w") as f:
            json.dump({"bytes": n, "md5": hashlib.md5(datos[:n]).hexdigest(),
                       "terminada": bool(fin and n == len(datos))}, f)

    if desde == len(datos):
        # Nada nuevo: solo se avisa que la sesión cerró.
        st, r = llamar(gateway, llave, {"action": "motor-sesion", "paso": "registrar", "session_id": sid,
                                        "offset": desde, "bytes": 0, "meta": meta})
        if st == 200:
            guardar(desde)
        else:
            log(f"{sid}: cierre {st} {r.get('error', '')}")
        return

    reintento = False
    while desde < len(datos):
        fin_parte = min(desde + PARTE, len(datos))
        if fin_parte < len(datos):
            nl = datos.rfind(b"\n", desde, fin_parte)
            fin_parte = nl + 1 if nl >= desde else datos.find(b"\n", fin_parte) + 1
        parte = datos[desde:fin_parte]
        st, r = llamar(gateway, llave, {"action": "motor-sesion", "paso": "subir", "session_id": sid, "offset": desde})
        if st == 409 and desde > 0 and not reintento:
            # Lo guardado en el OS no calza con esta máquina: de cero.
            reintento, desde = True, 0
            continue
        if st == 403:
            # La llave no entrena formatos: esta sesión no se guarda.
            log(f"{sid}: {r.get('error', 'sin permiso')}")
            return
        if st != 200:
            log(f"{sid}: subir {st} {r.get('error', '')}")
            return
        poner(r["url"], gzip.compress(parte, 6))
        st, r = llamar(gateway, llave, {"action": "motor-sesion", "paso": "registrar", "session_id": sid,
                                        "offset": desde, "bytes": len(parte), "meta": meta})
        if st != 200:
            log(f"{sid}: registrar {st} {r.get('error', '')}")
            return
        desde += len(parte)
        guardar(desde)
    log(f"{sid}: {len(datos)} bytes en el OS{' (cerrada)' if fin else ''}")


# ── Hook ──

def hook():
    try:
        evento = json.load(sys.stdin)
    except ValueError:
        return
    cwd = evento.get("cwd") or ""
    ruta = evento.get("transcript_path") or ""
    if not ruta or not os.path.isfile(ruta) or not es_del_motor(cwd):
        return
    fin = evento.get("hook_event_name") == "SessionEnd"
    args = [sys.executable, os.path.abspath(__file__), "subir", ruta, "--cwd", cwd] + (["--fin"] if fin else [])
    subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
    # La persona lo ve en pantalla una vez por sesión, no solo en la guía.
    sid = os.path.splitext(os.path.basename(ruta))[0]
    avisada = os.path.join(ESTADO, sid + ".avisada")
    if not fin and not os.path.exists(avisada):
        os.makedirs(ESTADO, exist_ok=True)
        open(avisada, "w").close()
        print(json.dumps({"systemMessage": AVISO}, ensure_ascii=False))


# ── Todas e instalar ──

def cwd_de(ruta):
    try:
        with open(ruta, "rb") as f:
            for i, linea in enumerate(f):
                if i > 200:
                    break
                try:
                    c = json.loads(linea).get("cwd")
                except ValueError:
                    continue
                if c:
                    return c
    except OSError:
        pass
    return None


def todas():
    n = 0
    for ruta in sorted(glob.glob(os.path.join(PROYECTOS, "*", "*.jsonl"))):
        cwd = cwd_de(ruta)
        if es_del_motor(cwd):
            subir(ruta, fin=False, cwd=cwd)
            n += 1
    log(f"todas: {n} sesiones del motor revisadas")
    return n


def es_nuestro(h):
    return (h.get("command") or "").rstrip().endswith('sesiones.py" hook')


def puede_guardar(cfg):
    """¿Alguna llave de la máquina guarda sesiones? Solo las de una persona
    del equipo con permiso para entrenar formatos; la llave de la cuenta de
    un cliente nunca. Lo decide el OS. None si el OS no respondió."""
    gateway = os.environ.get("ENGINE_GATEWAY_URL") or cfg.get("ENGINE_GATEWAY_URL") or "https://app.ianomads.com"
    llaves = {v for k, v in cfg.items() if k.startswith("ENGINE_SECRET") and v}
    respondio = False
    for llave in llaves:
        try:
            st, _ = llamar(gateway, llave, {"action": "motor-sesion", "paso": "puede"}, timeout=15)
        except Exception:
            continue
        if st == 200:
            return True
        respondio = respondio or st in (401, 403)
    return False if respondio or not llaves else None


def instalar():
    """Pone (o quita) el hook. Va solo si alguna llave de la máquina es de
    una persona que entrena formatos: si no, se quita el que hubiera."""
    comando = f'python3 "{os.path.abspath(__file__)}" hook'
    va = puede_guardar(leer_config())
    if va is None:
        return 0  # el OS no respondió: se deja como está
    try:
        with open(SETTINGS) as f:
            cfg = json.load(f)
    except FileNotFoundError:
        cfg = {}
    except ValueError:
        print(f"✗ {SETTINGS} no es JSON válido: no se toca. Las sesiones no se guardan hasta arreglarlo.")
        return 1
    hooks = cfg.setdefault("hooks", {})
    estaba = any(es_nuestro(h) for g in hooks.get("Stop", []) for h in g.get("hooks", []))
    if not va and not estaba:
        return 0
    for evento in ("Stop", "SessionEnd"):
        grupos = []
        for g in hooks.get(evento, []):
            resto = [h for h in g.get("hooks", []) if not es_nuestro(h)]
            if resto:
                grupos.append({**g, "hooks": resto})
        if va:
            grupos.append({"hooks": [{"type": "command", "command": comando, "timeout": 10}]})
        if grupos:
            hooks[evento] = grupos
        else:
            hooks.pop(evento, None)
    if not hooks:
        cfg.pop("hooks")
    os.makedirs(os.path.dirname(SETTINGS), exist_ok=True)
    tmp = SETTINGS + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, SETTINGS)
    if not va:
        print("· Las sesiones de este computador ya no se guardan en el OS.")
        return 0
    # Las sesiones que ya existen suben una vez, aparte, sin esperar.
    subprocess.Popen([sys.executable, os.path.abspath(__file__), "todas"], stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    if not estaba:
        print("✓ Desde ahora las sesiones de trabajo con el motor en este computador quedan guardadas "
              "en el OS de IA Nomads para mejorar el sistema. Díselo a la persona con estas palabras.")
    return 0


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else ""
    try:
        if cmd == "hook":
            hook()
        elif cmd == "subir" and len(args) > 1:
            cwd = args[args.index("--cwd") + 1] if "--cwd" in args else cwd_de(args[1])
            subir(args[1], fin="--fin" in args, cwd=cwd)
        elif cmd == "todas":
            print(f"{todas()} sesiones del motor revisadas")
        elif cmd == "instalar":
            return instalar()
        else:
            print(__doc__)
    except Exception as e:  # nunca romper la sesión de nadie
        log(f"{cmd}: {type(e).__name__}: {e}")
        if cmd == "instalar":
            print(f"✗ No se pudo instalar el guardado de sesiones: {e}")
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
