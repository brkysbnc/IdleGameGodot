class_name GameMain
extends Control
## B7-B10: scene composition only. Economy, content and the shop keep their APIs.

@onready var world: StarSystem = %StarSystem
@onready var hud: GameHUD = %HUD
@onready var effects: ClickEffects = %ClickEffects
@onready var sound: Node = $SoundFeedback
@onready var orbiter_label: Label = %OrbiterCount

var debug_panel: GameDebugPanel
var _count_timer: Timer


func _enter_tree() -> void:
	theme = GameTheme.make_theme()


func _ready() -> void:
	world.star.clicked.connect(_on_star_clicked)
	%MuteButton.pressed.connect(_toggle_sound)
	%CenterView.pressed.connect(world.camera.reset_view)
	if OS.has_feature("mobile"):
		get_node("SafeArea/Layout/Stage/Footer/Hint").text = "Yıldıza dokun • Sürükleyerek dön • İki parmakla yakınlaş"
	_count_timer = Timer.new()
	_count_timer.wait_time = 0.1
	_count_timer.one_shot = true
	_count_timer.timeout.connect(_update_orbiter_count)
	add_child(_count_timer)
	EventBus.orbiter_count_changed.connect(_on_count_changed)
	_update_orbiter_count()
	if OS.is_debug_build():
		debug_panel = GameDebugPanel.new()
		debug_panel.orbit_manager = world.orbit_manager
		debug_panel.z_index = 20
		add_child(debug_panel)
		_position_debug()
		resized.connect(_position_debug)
		%DebugCorner.pressed.connect(debug_panel.register_corner_tap)
	else:
		%DebugCorner.queue_free()


func _position_debug() -> void:
	if is_instance_valid(debug_panel):
		debug_panel.position = Vector2(size.x - 680, 180)


func _on_star_clicked(amount: BigNumber) -> void:
	var center := world.camera.unproject_position(world.star.global_position)
	effects.show_gain(amount, center)
	sound.play_click()


func _toggle_sound() -> void:
	sound.enabled = not sound.enabled
	%MuteButton.text = "Ses: açık" if sound.enabled else "Ses: kapalı"


func _on_count_changed(_id: StringName, _count: int) -> void:
	if _count_timer.is_stopped():
		_count_timer.start()


func _update_orbiter_count() -> void:
	var total := 0
	for data in GameData.orbiters():
		total += GameState.get_orbiter_count(data.id)
	orbiter_label.text = "%s gök cismi" % total
