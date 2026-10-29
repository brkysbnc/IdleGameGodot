class_name ShopList
extends ScrollContainer
## Dikey kaydırılabilir liste (A5/A6). Satırlar `list` içine eklenir.
## Dokunmatikte sürükleyerek kaydırılır, yatay kaydırma kapalı.

var list: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_deadzone = ShopStyle.SCROLL_DEADZONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", ShopStyle.ROW_SPACING)
	add_child(list)


## Satırları kaldırır. Hemen çıkarılır (bir butonun kendi basma sinyali içinden çağrılsa
## bile güvenli), bellekten sonra serbest bırakılır.
func clear() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
