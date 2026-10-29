extends Node
## Short synthesized sounds, allocated once; no external audio dependency.

const VOICES := 4
const SAMPLE_RATE := 22050

var enabled: bool = true
var _players: Array[AudioStreamPlayer] = []
var _click: AudioStreamWAV
var _purchase: AudioStreamWAV
var _next: int = 0
var _last_click_msec: int = -100


func _ready() -> void:
	_click = _tone([740.0, 1108.0], 0.075)
	_purchase = _tone([523.25, 659.25, 783.99], 0.19)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = -21.0
		add_child(player)
		_players.append(player)
	EventBus.upgrade_purchased.connect(_on_upgrade)
	EventBus.orbiter_count_changed.connect(_on_orbiter)


func play_click() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_click_msec >= 45:
		_last_click_msec = now
		_play(_click)


func _on_upgrade(_id: StringName) -> void:
	_play(_purchase)


func _on_orbiter(_id: StringName, count: int) -> void:
	if count > 0:
		_play(_purchase)


func _play(stream: AudioStreamWAV) -> void:
	if not enabled:
		return
	var voice := _players[_next]
	_next = (_next + 1) % VOICES
	voice.stream = stream
	voice.play()


func _tone(frequencies: Array[float], duration: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in count:
		var time := float(i) / SAMPLE_RATE
		var envelope := sin(PI * float(i) / count) * exp(-time * 15.0)
		var value := 0.0
		for frequency in frequencies:
			value += sin(TAU * frequency * time)
		samples.encode_s16(i * 2, int(value / frequencies.size() * envelope * 11000.0))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = SAMPLE_RATE
	result.data = samples
	return result
