extends SceneTree
## Economy testleri (A3). Autoload'lar gerekir (_initialize). Çalıştırma:
##   godot --headless --path . --script res://tests/economy_test.gd
## Upgrade testleri, gerçek UpgradeSystem (B1) yoksa (stub) atlanır.
## Çıkış kodu: 0 = tamam, 1 = hata.

var _failed: int = 0
var _income_events: Array = []
var _upgrade_events: Array = []


func _initialize() -> void:
	for autoload in ["EventBus", "GameState", "Economy", "UpgradeSystem"]:
		if not root.has_node(autoload):
			printerr("HATA: '%s' autoload'u yok. Testi proje klasorunden --path . ile calistirin." % autoload)
			quit(1)
			return
	EventBus.income_changed.connect(func(per_sec: BigNumber) -> void: _income_events.append(per_sec))
	EventBus.upgrade_purchased.connect(func(id: StringName) -> void: _upgrade_events.append(id))
	_test_click()
	_test_orbiter_cost_curve()
	_test_buy_orbiter()
	_test_income_and_tick()
	if UpgradeSystem.has_method("register_definitions"):
		_test_upgrades()
	else:
		print("ATLANDI: upgrade testleri (UpgradeSystem hala stub, B1 merge edilince calisir)")
	if _failed == 0:
		print("Economy testleri: TAMAM")
	else:
		printerr("Economy testleri: %d HATA" % _failed)
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if not condition:
		_failed += 1
		printerr("BASARISIZ: ", name)


func _near(a: float, b: float) -> bool:
	return absf(a - b) <= absf(b) * 1e-9 + 1e-12


func _fresh() -> void:
	UpgradeSystem.deserialize({})
	GameState.deserialize({})
	Economy.refresh()
	_income_events.clear()
	_upgrade_events.clear()


func _give(amount: float) -> void:
	GameState.add_currency(BigNumber.from_float(amount))


func _test_click() -> void:
	_fresh()
	var gained: BigNumber = Economy.click()
	_check(_near(gained.to_float(), 1.0), "click degeri 1 (upgrade yok)")
	_check(GameState.get_currency().equals(gained), "click parayi artirir")
	_check(Economy.get_click_value().equals(gained), "get_click_value ile ayni")


func _test_orbiter_cost_curve() -> void:
	_fresh()
	_check(_near(Economy.get_orbiter_cost(&"dust_cloud").to_float(), 15.0), "ilk adet maliyeti 15")
	GameState.add_orbiter(&"dust_cloud")
	_check(_near(Economy.get_orbiter_cost(&"dust_cloud").to_float(), 17.25), "ikinci adet 15*1.15")
	GameState.add_orbiter(&"dust_cloud", 4) # toplam 5 adet
	_check(_near(Economy.get_orbiter_cost(&"dust_cloud").to_float(), 15.0 * pow(1.15, 5)), "alti. adet 15*1.15^5")


func _test_buy_orbiter() -> void:
	_fresh()
	_check(not Economy.try_buy_orbiter(&"dust_cloud"), "parasiz satin alma basarisiz")
	_check(Economy.get_orbiter_count(&"dust_cloud") == 0, "basarisiz alim sayiyi degistirmez")
	_check(not Economy.try_buy_orbiter(&"yok_boyle_orbiter"), "bilinmeyen orbiter alinamaz")
	_give(100.0)
	_check(Economy.try_buy_orbiter(&"dust_cloud"), "yeterli parayla satin alma")
	_check(Economy.get_orbiter_count(&"dust_cloud") == 1, "adet 1 oldu")
	_check(_near(GameState.get_currency().to_float(), 85.0), "maliyet 15 dusuldu")
	_check(_near(Economy.get_income_per_sec().to_float(), 0.1), "gelir 0.1/sn")
	_check(_income_events.size() >= 1, "satin alma income_changed sinyali atar")


func _test_income_and_tick() -> void:
	_fresh()
	GameState.add_orbiter(&"dust_cloud", 10) # 10 x 0.1 = 1.0/sn
	GameState.add_orbiter(&"asteroid", 2) # 2 x 1.0 = 2.0/sn
	_check(_near(Economy.get_income_per_sec().to_float(), 3.0), "gelir toplami 3.0/sn")
	_check(_near(Economy.get_orbiter_unit_income(&"asteroid").to_float(), 1.0), "orbiter basina gelir")
	_check(Economy.get_orbiter_unit_income(&"yok_boyle_orbiter").is_zero(), "bilinmeyen orbiter geliri 0")
	Economy.process_elapsed(0.5)
	_check(_near(GameState.get_currency().to_float(), 1.5), "0.5 sn x 3.0 = 1.5")
	GameState.deserialize({})
	Economy.refresh()
	_check(Economy.get_income_per_sec().is_zero(), "refresh sonrasi gelir 0")
	GameState.add_orbiter(&"asteroid", 1)
	var before := GameState.get_currency().to_float()
	Economy.process_elapsed(100.0) # ust sinir: en fazla MAX_CATCHUP_SECONDS
	_check(_near(GameState.get_currency().to_float() - before, 1.0 * Economy.MAX_CATCHUP_SECONDS), "tek tickte ust sinir")
	Economy.process_elapsed(0.0)
	Economy.process_elapsed(-1.0)
	_check(_near(GameState.get_currency().to_float() - before, 1.0), "sifir/negatif sure gelir eklemez")


func _test_upgrades() -> void:
	_fresh()
	_check(not Economy.try_buy_upgrade(&"click_power_1"), "parasiz upgrade alinamaz")
	_give(1000000000.0)
	_check(Economy.try_buy_upgrade(&"click_power_1"), "click_power_1 alinir")
	_check(UpgradeSystem.is_purchased(&"click_power_1"), "satin alinan isaretlenir")
	_check(_upgrade_events.has(&"click_power_1"), "upgrade_purchased sinyali")
	_check(_near(Economy.get_click_value().to_float(), 2.0), "tik degeri x2")
	_check(not Economy.try_buy_upgrade(&"click_power_1"), "ayni upgrade ikinci kez alinamaz")
	_check(not Economy.try_buy_upgrade(&"yok_boyle_upgrade"), "bilinmeyen upgrade alinamaz")

	GameState.add_orbiter(&"dust_cloud", 10)
	_check(_near(Economy.get_income_per_sec().to_float(), 1.0), "upgrade oncesi gelir 1.0")
	_check(Economy.try_buy_upgrade(&"dust_cloud_boost"), "orbiter upgrade alinir")
	_check(_near(Economy.get_income_per_sec().to_float(), 2.0), "orbiter upgrade geliri x2")
	_check(Economy.try_buy_upgrade(&"all_orbiters_1"), "all_orbiters upgrade alinir")
	_check(_near(Economy.get_income_per_sec().to_float(), 4.0), "all_orbiters geliri x2 daha")
	_check(Economy.try_buy_upgrade(&"all_income_1"), "all_income upgrade alinir")
	_check(_near(Economy.get_income_per_sec().to_float(), 6.0), "all_income x1.5")
	_check(_near(Economy.get_click_value().to_float(), 3.0), "all_income tiki da etkiler (2 x 1.5)")
