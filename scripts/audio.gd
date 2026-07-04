extends Node
## Autoload sound manager. Pooled one-shot SFX with pitch variance and spam
## throttling, looping music with a runtime "Music" bus, and the Desperation
## treatment from GDD 3.3: music ducks + muffles under a heartbeat.

const DIR := "res://assets/audio/"
const POOL_SIZE := 10
const THROTTLE_MS := 50  # min gap between two starts of the SAME sfx

var _streams: Dictionary = {}          # name -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer = null
var _bind: AudioStreamPlayer = null    # Soul Bind channel hum (loop)
var _heart: AudioStreamPlayer = null   # Desperation heartbeat (loop)
var _last_start: Dictionary = {}       # name -> ticks msec
var _current_music: String = ""
var _music_bus: int = -1
var _lowpass: AudioEffectLowPassFilter = null

func _ready() -> void:
	# Music gets its own bus so Desperation can muffle it without touching SFX.
	_music_bus = AudioServer.bus_count
	AudioServer.add_bus(_music_bus)
	AudioServer.set_bus_name(_music_bus, "Music")
	AudioServer.set_bus_send(_music_bus, "Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 620.0
	AudioServer.add_bus_effect(_music_bus, _lowpass)
	AudioServer.set_bus_effect_enabled(_music_bus, 0, false)

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -10.0
	add_child(_music)
	_bind = AudioStreamPlayer.new()
	_bind.volume_db = -14.0
	add_child(_bind)
	_heart = AudioStreamPlayer.new()
	_heart.volume_db = -4.0
	add_child(_heart)

## Fetch (and cache) a stream; optionally mark it as a seamless loop.
func _stream(name: String, looped: bool = false) -> AudioStreamWAV:
	if not _streams.has(name):
		var s: AudioStreamWAV = load(DIR + name + ".wav")
		if s == null:
			return null
		if looped:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2  # 16-bit mono: 2 bytes per frame
		_streams[name] = s
	return _streams[name]

## Fire a one-shot effect. Throttled per-name so a crowd of simultaneous hits
## doesn't stack into clipping.
func sfx(name: String, vol_db: float = 0.0, pitch_var: float = 0.08) -> void:
	var now: int = Time.get_ticks_msec()
	if _last_start.has(name) and now - _last_start[name] < THROTTLE_MS:
		return
	var s: AudioStreamWAV = _stream(name)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			_last_start[name] = now
			p.stream = s
			p.volume_db = vol_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return
	# Pool exhausted: drop the sound (better than cutting one mid-flight).

## Swap the looping background track ("music_run" / "music_hub").
func play_music(name: String) -> void:
	if _current_music == name:
		return
	_current_music = name
	var s: AudioStreamWAV = _stream(name, true)
	if s == null:
		return
	_music.stop()
	_music.stream = s
	_music.volume_db = -10.0
	_music.play()

## Soul Bind channel hum on/off (loops while channeling).
func bind_hum(on: bool) -> void:
	if on and not _bind.playing:
		_bind.stream = _stream("bind_hum", true)
		_bind.play()
	elif not on:
		_bind.stop()

## Desperation Mode (GDD 3.3): "the audio muffles and a heartbeat plays".
func set_desperation(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(_music_bus, 0, on)
	_music.volume_db = -20.0 if on else -10.0
	if on:
		if not _heart.playing:
			_heart.stream = _stream("heartbeat", true)
			_heart.play()
	else:
		_heart.stop()
