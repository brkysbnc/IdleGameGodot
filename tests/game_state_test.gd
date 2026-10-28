extends SceneTree
## GameState testleri (A2). Autoload'lar gerekir, bu yüzden _initialize kullanılır. Çalıştırma:
##   godot --headless --path . --script res://tests/game_state_test.gd
## Çıkış kodu: 0 = tamam, 1 = hata.

var _failed: int = 0
var _currency_events: Array = []
var _orbiter_events: Array = []


func _initialize() -> void:
	if not root.has_node("GameState") or not root.has_node("EventBus"):
		printerr("HATA: autoload'lar yok. Testi proje klasorunden --path . ile calistirin.")
		quit(1)
		return
	EventBus.currency_changed.connect(func(amount: BigNumber) -> void: _currency_events.append(amount))
	EventBus.orbiter_count_changed.connect(func(id: StringName, count: int) -> void: _orbiter_events.append([id, count]))
	_test_currency()
	_test_orbiters()
	_test_save_roundtrip()
	_test_bad_data()
	if _failed == 0:
		print("GameState testleri: TAMAM")
	else:
		printerr("GameState testleri: %d HATA" % _failed)
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if not condition:
		_failed += 1
		printerr("BASARISIZ: ", name)


func _reset() -> void:
	GameState.deserialize({})
	_currency_events.clear()
	_orbiter_events.clear()


func _test_currency() -> void:
	_reset()
	_check(GameState.get_currency().is_zero(), "baslangic parasi 0")
	GameState.add_currency(BigNumber.from_float(100.0))
	_check(GameState.get_currency().equals(BigNumber.from_float(100.0)), "add_currency")
	_check(_currency_events.size() == 1, "add_currency sinyal atar")
	GameState.add_currency(BigNumber.zero())
	_check(_currency_events.size() == 1, "sifir eklemek sinyal atmaz")
	_check(GameState.try_spend(BigNumber.from_float(40.0)), "try_spend yeterli para")
	_check(GameState.get_currency().equals(BigNumber.from_float(60.0)), "try_spend sonrasi bakiye")
	var events_before := _currency_events.size()
	_check(not GameState.try_spend(BigNumber.from_float(100.0)), "try_spend yetersiz para false")
	_check(GameState.get_currency().equals(BigNumber.from_float(60.0)), "basarisiz harcama bakiyeyi degistirmez")
	_check(_currency_events.size() == events_before, "basarisiz harcama sinyal atmaz")
	_check(GameState.try_spend(BigNumber.from_float(60.0)), "tam bakiyeyi harcamak")
	_check(GameState.get_currency().is_zero(), "tam harcama sonrasi 0")


func _test_orbiters() -> void:
	_reset()
	_check(GameState.get_orbiter_count(&"moon") == 0, "baslangic orbiter sayisi 0")
	GameState.add_orbiter(&"moon")
	_check(GameState.get_orbiter_count(&"moon") == 1, "add_orbiter +1")
	_check(_orbiter_events.size() == 1 and _orbiter_events[0][0] == &"moon" and _orbiter_events[0][1] == 1, "add_orbiter sinyali (id, sayi)")
	GameState.add_orbiter(&"moon", 2)
	_check(GameState.get_orbiter_count(&"moon") == 3, "add_orbiter +2")
	GameState.add_orbiter(&"moon", 0)
	GameState.add_orbiter(&"moon", -5)
	_check(GameState.get_orbiter_count(&"moon") == 3, "gecersiz miktar yok sayilir")


func _test_save_roundtrip() -> void:
	_reset()
	GameState.add_currency(BigNumber.from_float(1234.5))
	GameState.add_orbiter(&"moon", 3)
	GameState.add_orbiter(&"planet", 1)
	var json_text: String = JSON.stringify(GameState.serialize())
	var loaded: Dictionary = JSON.parse_string(json_text)
	_reset()
	GameState.deserialize(loaded)
	_check(GameState.get_currency().equals(BigNumber.from_float(1234.5)), "roundtrip para")
	_check(GameState.get_orbiter_count(&"moon") == 3, "roundtrip moon")
	_check(GameState.get_orbiter_count(&"planet") == 1, "roundtrip planet")
	_check(_currency_events.size() >= 1 and _orbiter_events.size() == 2, "deserialize durumu sinyallerle duyurur")


func _test_bad_data() -> void:
	_reset()
	GameState.deserialize({"currency": 5, "orbiters": "x"})
	_check(GameState.get_currency().is_zero(), "bozuk para -> 0")
	GameState.deserialize({"orbiters": {"yok_boyle_orbiter": 4, "moon": 2, "planet": -1}})
	_check(GameState.get_orbiter_count(&"yok_boyle_orbiter") == 0, "bilinmeyen orbiter atlanir")
	_check(GameState.get_orbiter_count(&"moon") == 2, "gecerli orbiter yuklenir")
	_check(GameState.get_orbiter_count(&"planet") == 0, "negatif sayi atlanir")
