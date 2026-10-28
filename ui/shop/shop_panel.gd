class_name ShopPanel
extends PanelContainer
## Sağ mağaza paneli (A5): üstte Orbiters listesi ve sağ üstte Orbiter Upgrade menüsü
## butonu, altında genel Upgrades listesi. Listeler `data/` içindeki .tres'lerden otomatik dolar.
##
## Güncelleme sinyalle yapılır, her karede değil: para değişimi en fazla ~10 Hz'de buton
## aktifliğini yeniler, metinler sadece gelir/adet değişince (income_changed) üretilir.
## Yerleşim: `shop_panel.tscn` sahnesini main.tscn'e instance edip sağa konumlandır (B9, #18).

const BASE_MARGIN := 12

var _margin: MarginContainer
var _orbiter_rows: Array[OrbiterRow] = []
var _upgrade_rows: Array[UpgradeRow] = []
var _menu: OrbiterUpgradeMenu
var _refresh_timer: Timer


func _ready() -> void:
	_build_ui()
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = ShopStyle.REFRESH_INTERVAL
	_refresh_timer.one_shot = true
	_refresh_timer.timeout.connect(_on_refresh_timeout)
	add_child(_refresh_timer)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.income_changed.connect(_on_income_changed)
	get_window().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func _build_ui() -> void:
	_margin = MarginContainer.new()
	add_child(_margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", ShopStyle.ROW_SPACING)
	_margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := ShopStyle.make_label()
	title.text = "Orbiters"
	header.add_child(title)
	var menu_button := Button.new()
	menu_button.text = "Yükseltmeler"
	menu_button.custom_minimum_size = Vector2(ShopStyle.BUY_BUTTON_WIDTH, ShopStyle.MIN_TOUCH_SIZE)
	menu_button.add_theme_font_size_override("font_size", ShopStyle.FONT_SIZE_SMALL)
	menu_button.pressed.connect(func() -> void: _menu.open_menu())
	header.add_child(menu_button)

	var orbiter_list := ShopList.new()
	orbiter_list.size_flags_stretch_ratio = 3.0
	root.add_child(orbiter_list)
	for data in GameData.orbiters():
		var row := OrbiterRow.new().setup(data)
		orbiter_list.list.add_child(row)
		_orbiter_rows.append(row)

	var upgrades_title := ShopStyle.make_label()
	upgrades_title.text = "Upgrades"
	root.add_child(upgrades_title)
	var upgrade_list := ShopList.new()
	upgrade_list.size_flags_stretch_ratio = 2.0
	root.add_child(upgrade_list)
	for data in GameData.general_upgrades():
		var row := UpgradeRow.new().setup(data)
		upgrade_list.list.add_child(row)
		_upgrade_rows.append(row)

	_menu = OrbiterUpgradeMenu.new()
	add_child(_menu) # PanelContainer çocukları üst üste bindirir, menü en üstte görünür


## Gelir, adet ya da upgrade değişti (satın alma ya da kayıt yükleme): metinleri yenile.
func _on_income_changed(_per_sec: BigNumber) -> void:
	for row in _orbiter_rows:
		row.refresh_full()
	for row in _upgrade_rows:
		row.refresh_state()


## Para değişimini birleştirir: en fazla ShopStyle.REFRESH_INTERVAL'de bir yenileme.
func _on_currency_changed(_amount: BigNumber) -> void:
	if _refresh_timer.is_stopped():
		_refresh_timer.start()


func _on_refresh_timeout() -> void:
	for row in _orbiter_rows:
		row.refresh_affordability()
	for row in _upgrade_rows:
		row.refresh_state()
	_menu.refresh_affordability()


## Mobilde çentik/gezinme çubuğu altında kalmasın. Masaüstünde etkisizdir.
func _apply_safe_area() -> void:
	var top := BASE_MARGIN
	var right := BASE_MARGIN
	var bottom := BASE_MARGIN
	var left := BASE_MARGIN
	if OS.has_feature("mobile"):
		var window_size := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var scale := maxf(get_window().get_final_transform().get_scale().x, 0.001)
		top += int(maxf(0.0, safe.position.y) / scale)
		left += int(maxf(0.0, safe.position.x) / scale)
		right += int(maxf(0.0, window_size.x - safe.end.x) / scale)
		bottom += int(maxf(0.0, window_size.y - safe.end.y) / scale)
	_margin.add_theme_constant_override("margin_top", top)
	_margin.add_theme_constant_override("margin_left", left)
	_margin.add_theme_constant_override("margin_right", right)
	_margin.add_theme_constant_override("margin_bottom", bottom)
