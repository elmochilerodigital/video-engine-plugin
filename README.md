# video-engine-plugin

Plugin de Claude Code para producir videos verticales 9:16 de marca con el motor de IA Nomads (Remotion + ffmpeg + whisper). Thin loader: jala el motor y la marca frescos de la nube; no contiene el motor ni secretos.

## Instalar

```
/plugin marketplace add elmochilerodigital/video-engine-plugin
/plugin install video-engine@video-engine-plugin
```

El skill pedirá tu `api_secret` (te la da IA Nomads) en el primer uso y la guarda en `~/.ia-nomads/config`. Sin una llave válida, el motor y la marca no se descargan (401).
