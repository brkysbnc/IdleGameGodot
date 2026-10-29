class_name GameTheme
extends RefCounted
## Shared appearance; also styles the existing shop without editing A-owned files.

const INK := Color("080e1d")
const PANEL := Color("101b30")
const BORDER := Color("2b3c58")
const TEXT := Color("eaf0fa")
const MUTED := Color("94a9c5")
const GOLD := Color("ffd491")
const MINT := Color("83ddca")


static func panel(color: Color = PANEL, radius: int = 18, padding: int = 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 30
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", GOLD)
	result.set_color("font_pressed_color", "Button", GOLD)
	result.set_color("font_disabled_color", "Button", Color("687a94"))
	result.set_stylebox("panel", "PanelContainer", panel())
	result.set_stylebox("normal", "Button", panel(Color("1c2d46"), 12, 12))
	var hover := panel(Color("293d58"), 12, 12)
	hover.border_color = GOLD
	result.set_stylebox("hover", "Button", hover)
	result.set_stylebox("pressed", "Button", panel(Color("34445a"), 12, 12))
	result.set_stylebox("disabled", "Button", panel(Color("152035"), 12, 12))
	var focus := panel(Color(0, 0, 0, 0), 12, 0)
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 20)
	return result


static func label(text: String, font_size: int = 30, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
