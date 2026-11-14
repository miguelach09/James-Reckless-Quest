extends Node
## Música de fondo global con fundido entre pistas (autoload "MusicManager").
##
## CÓMO PONER TU MÚSICA:
##   1. Arrastra tus MP3 a la carpeta  res://audio/  del proyecto
##      (créala en el panel Sistema de Archivos si no existe todavía).
##   2. Renómbralos así (o cambia las rutas en TRACKS más abajo):
##        res://audio/music_title.mp3  ->  menú / portada
##        res://audio/music_game.mp3   ->  mientras se juega
##        res://audio/music_boss.mp3   ->  jefe final
##   3. Ya está: el juego los reproduce solo. Si un archivo aún no existe,
##      se ignora sin errores, así puedes añadir la música de a poco.

const TRACKS := {
	"title": "res://audio/music_title.mp3",
	"game": "res://audio/music_game.mp3",
	"boss": "res://audio/music_boss.mp3",
}
const FADE_TIME := 1.0
const SILENT_DB := -60.0

@export var volume_db: float = -8.0

var _players: Array[AudioStreamPlayer] = []
var _current: AudioStreamPlayer = null
var _current_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)


## Reproduce la pista asociada a "key": "title", "game" o "boss", con fundido.
func play(key: String) -> void:
	if key == _current_key:
		return
	_current_key = key
	var path: String = str(TRACKS.get(key, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	# Los MP3/OGG deben repetirse en bucle.
	stream.set("loop", true)

	var prev: AudioStreamPlayer = _current
	_current = _players[1] if prev == _players[0] else _players[0]
	_current.stream = stream
	_current.volume_db = SILENT_DB
	_current.play()
	_fade(_current, volume_db, FADE_TIME)
	if prev != null and prev.playing:
		_fade(prev, SILENT_DB, FADE_TIME)
		var out: Tween = create_tween()
		out.tween_interval(FADE_TIME)
		out.tween_callback(prev.stop)


func stop(fade: bool = true) -> void:
	_current_key = ""
	if _current == null:
		return
	if fade:
		var last: AudioStreamPlayer = _current
		_fade(last, SILENT_DB, FADE_TIME)
		var out: Tween = create_tween()
		out.tween_interval(FADE_TIME)
		out.tween_callback(last.stop)
	else:
		_current.stop()


func _fade(p: AudioStreamPlayer, to_db: float, time: float) -> void:
	var t: Tween = create_tween()
	t.tween_property(p, "volume_db", to_db, time)