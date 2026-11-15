extends Node
## Autoload "Music": musik latar yang berulang, pindah lagu dengan crossfade.
## Lagu: "menu" (semua layar di luar permainan), "indonesia" (gamelan, level Warung Nusantara), "umum" (area lain).

const TRACKS := {
	"menu": "res://assets/audio/musik_menu.wav",
	"indonesia": "res://assets/audio/musik_indonesia.wav",
	"umum": "res://assets/audio/musik_umum.wav",
}
const MUSIC_DB := -9.0     # volume musik (efek suara tetap lebih menonjol)
const FADE := 0.7          # detik crossfade

var track: String = ""
var _active: AudioStreamPlayer
var _old: AudioStreamPlayer
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_buses()
	apply_volumes()
	_active = _make_player()
	_old = _make_player()


## Buat bus "Musik" dan "Efek" (sekali saja) agar volume keduanya bisa diatur terpisah.
static func setup_buses() -> void:
	for nm in ["Musik", "Efek"]:
		if AudioServer.get_bus_index(nm) == -1:
			AudioServer.add_bus()
			var i := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(i, nm)
			AudioServer.set_bus_send(i, "Master")


## Terapkan volume tersimpan (0..1) ke bus; 0 = bisu penuh.
static func apply_volumes() -> void:
	for pair in [["Musik", GameState.music_vol], ["Efek", GameState.sfx_vol]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i == -1:
			continue
		var v: float = pair[1]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Musik"
	p.volume_db = -80.0
	add_child(p)
	return p


## Lagu untuk sebuah layar: gameplay memakai lagu areanya, layar lain memakai lagu menu.
static func track_for(screen: String, params: Dictionary) -> String:
	if screen == "gameplay":
		return "indonesia" if int(params.get("area", 0)) == 0 and not bool(params.get("classic", false)) else "umum"
	return "menu"


func play(name: String) -> void:
	if name == track or not TRACKS.has(name):
		return
	track = name
	var st: AudioStreamWAV = load(TRACKS[name])
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = st.data.size() / 2   # mono 16-bit
	var tmp := _old
	_old = _active
	_active = tmp
	_active.stream = st
	_active.volume_db = -60.0
	_active.play()
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_active, "volume_db", MUSIC_DB, FADE)
	if _old.playing:
		_tween.tween_property(_old, "volume_db", -60.0, FADE)
		_tween.chain().tween_callback(_old.stop)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_active.stream_paused = true
		_old.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_active.stream_paused = false
		_old.stream_paused = false
