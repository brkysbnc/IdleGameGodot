class_name OrbiterUpgradeMenu
extends PanelContainer
## Orbiter Upgrade menüsü (A6): sahip olunan orbiter'lara özel gelir upgrade'leri.
## Mağaza panelinin üstüne bindirme olarak açılır. Geri tuşu (Android) / Esc kapatır.

var _list: ShopList


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", ShopStyle.make_overlay_style())
	var root := VBoxContainer.new()
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := ShopStyle.make_label()
	title.text = "Orbiter Yükseltmeleri"
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(ShopStyle.MIN_TOUCH_SIZE, ShopStyle.MIN_TOUCH_SIZE)
	close_button.add_theme_font_size_override("font_size", ShopStyle.FONT_SIZE)
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)

	_list = ShopList.new()
	root.add_child(_list)
	EventBus.income_changed.connect(_on_income_changed)


func open_menu() -> void:
	_rebuild()
	visible = true


func close_menu() -> void:
	visible = false


## Para değişince buton aktifliğini yeniler (panelin 10 Hz zamanlayıcısından çağrılır).
func refresh_affordability() -> void:
	if not visible:
		return
	for row in _list.list.get_children():
		if row is UpgradeRow:
			row.refresh_state()


func _on_income_changed(_per_sec: BigNumber) -> void:
	# Satın alma ya da kayıt yükleme: alınan upgrade'ler listeden düşsün.
	if visible:
		_rebuild()


func _rebuild() -> void:
	_list.clear()
	var any_available := false
	for orbiter in GameData.orbiters():
		if Economy.get_orbiter_count(orbiter.id) == 0:
			continue
		var available: Array[UpgradeData] = []
		for upgrade in GameData.upgrades_for_orbiter(orbiter.id):
			if not UpgradeSystem.is_purchased(upgrade.id):
				available.append(upgrade)
		if available.is_empty():
			continue
		any_available = true
		var header := ShopStyle.make_label()
		header.text = orbiter.display_name
		_list.list.add_child(header)
		for upgrade in available:
			_list.list.add_child(UpgradeRow.new().setup(upgrade))
	if not any_available:
		var empty := ShopStyle.make_label(ShopStyle.FONT_SIZE_SMALL)
		empty.text = "Şu an alınabilir yükseltme yok. Yeni bir orbiter satın al."
		_list.list.add_child(empty)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Android geri tuşu: menü açıkken menüyü kapatır (uygulamadan atmaz).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		close_menu()
