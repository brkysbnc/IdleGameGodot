extends Node
## Mağaza paneli duman testi (A5/A6): sahne yüklenir, satırlar veriden oluşur, buton
## Economy'ye bağlıdır, orbiter menüsü sahip olunan orbiter'ın upgrade'ini listeler.
## Çalıştırma (autoload'lar gerekir):
##   godot --headless --path . res://tests/runner.tscn -- res://tests/shop_panel_test.gd
## Çıkış kodu: 0 = tamam, 1 = hata.

var _failed: int = 0


func _ready() -> void:
	for autoload in ["EventBus", "GameState", "Economy", "UpgradeSystem"]:
		if not get_tree().root.has_node(autoload):
			printerr("HATA: '%s' autoload'u yok. Testi proje klasorunden --path . ile calistirin." % autoload)
			get_tree().quit(1)
			return
	UpgradeSystem.deserialize({})
	GameState.deserialize({})
	Economy.refresh()

	var scene: PackedScene = load("res://ui/shop/shop_panel.tscn")
	_check(scene != null, "shop_panel.tscn yuklenir")
	if scene == null:
		get_tree().quit(1)
		return
	var panel: ShopPanel = scene.instantiate()
	add_child(panel)

	var orbiter_rows: Array = _collect(panel, OrbiterRow)
	_check(orbiter_rows.size() == GameData.orbiters().size(), "her orbiter icin bir satir")
	var upgrade_rows: Array = _collect(panel, UpgradeRow)
	_check(upgrade_rows.size() == GameData.general_upgrades().size(), "her genel upgrade icin bir satir")

	# Buton -> Economy baglantisi (butonlar ozel alan, test icin dogrudan erisiliyor).
	var first_row: OrbiterRow = orbiter_rows[0]
	_check(first_row._buy_button.disabled, "parasizken satin al butonu pasif")
	GameState.add_currency(BigNumber.from_float(1000.0))
	first_row.refresh_affordability()
	_check(not first_row._buy_button.disabled, "parayla buton aktif")
	first_row._buy_button.pressed.emit()
	_check(Economy.get_orbiter_count(GameData.orbiters()[0].id) == 1, "butona basinca orbiter alinir")

	# Orbiter upgrade menusu: sahip olunan orbiter'in upgrade'i listelenir.
	var menu: OrbiterUpgradeMenu = panel._menu
	_check(not menu.visible, "menu baslangicta kapali")
	menu.open_menu()
	_check(menu.visible, "menu acilir")
	var expected: int = GameData.upgrades_for_orbiter(GameData.orbiters()[0].id).size()
	_check(_collect(menu, UpgradeRow).size() == expected, "menu sahip olunan orbiter'in upgrade'lerini listeler")
	menu.close_menu()
	_check(not menu.visible, "menu kapanir")

	panel.queue_free()
	if _failed == 0:
		print("ShopPanel testleri: TAMAM")
	else:
		printerr("ShopPanel testleri: %d HATA" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if not condition:
		_failed += 1
		printerr("BASARISIZ: ", name)


## Alt agactaki belirli bir script sinifindaki tum dugumleri toplar.
func _collect(node: Node, script_class: Script) -> Array:
	var found: Array = []
	for child in node.get_children():
		if is_instance_of(child, script_class):
			found.append(child)
		found.append_array(_collect(child, script_class))
	return found
