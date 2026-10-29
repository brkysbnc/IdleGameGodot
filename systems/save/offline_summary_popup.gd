extends CanvasLayer
## B4 (#13). "Yokken X kazandin" ozet popup'i.
## Tamamen kodla kurulur (.tscn yok), boylece merge cakismasi ve sahne bagimliligi olmaz.
## Dokunmatik kurallari (#1): en az ~96 px dokunma hedefi, en az ~28 px yazi (1920x1080 tasarim cozunurlugunde).
## Oyunu durdurmaz. Arkadaki girdiyi yakalar, "Tamam"a basinca kapanir.
## class_name KULLANMA: preload ile yuklenir.

const LAYER_ON_TOP := 100
const FONT_SIZE := 32
const BUTTON_MIN_SIZE := Vector2(480.0, 96.0)
const PANEL_MIN_WIDTH := 720.0
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.6)

## Gosterilecek metin. add_child'dan once atanmali.
var message: String = ""


func _ready() -> void:
	layer = LAYER_ON_TOP

	# Arkadaki yildiza yanlislikla dokunulmasin diye tum ekrani kaplayip girdiyi yutar.
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_MIN_WIDTH
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 32)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 32)
	margin.add_child(column)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	column.add_child(label)

	var button := Button.new()
	button.text = "Tamam"
	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(queue_free)
	column.add_child(button)


## Saniyeyi "2 sa 15 dk" / "45 dk" seklinde yazar.
static func format_duration(seconds: float) -> String:
	var total_minutes := maxi(floori(seconds / 60.0), 0)
	var hours := floori(total_minutes / 60.0)
	var minutes := total_minutes - hours * 60
	if hours > 0:
		return "%d sa %d dk" % [hours, minutes]
	return "%d dk" % minutes
