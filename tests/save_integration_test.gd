extends Node
## Kayit + Economy entegrasyon testi: kaydedilmis upgrade'ler yukleme sonrasi gelire yansimali.
## Dinamik cagrilar (call/set) kullanir: SaveService stub iken de derlenir.
## Calistirma:
##   godot --headless --path . res://tests/runner.tscn -- res://tests/save_integration_test.gd
## Cikis kodu: 0 = tamam, 1 = hata.

const TEST_SAVE := "user://integration_test_save.json"

var _failed: int = 0


func _ready() -> void:
	# Gercek SaveService (B3) ve UpgradeSystem (B1) gerekir. Stub'ken atlanir.
	if not "save_path" in SaveService or not UpgradeSystem.has_method("register_definitions"):
		print("ATLANDI: kayit entegrasyon testi (SaveService/UpgradeSystem hala stub, B1+B3 merge edilince calisir)")
		get_tree().quit(0)
		return
	SaveService.set("save_path", TEST_SAVE)
	_reset()
	# 10 asteroit (1.0/sn) + asteroid_boost (x2) => 20/sn
	GameState.add_orbiter(&"asteroid", 10)
	GameState.add_currency(BigNumber.from_float(1000000.0))
	_check(Economy.try_buy_upgrade(&"asteroid_boost"), "upgrade satin alinir")
	_check(is_equal_approx(Economy.get_income_per_sec().to_float(), 20.0), "kayit oncesi gelir 20/sn")
	_check(SaveService.call("save_game") == true, "kayit yazilir")

	_reset()
	_check(Economy.get_income_per_sec().is_zero(), "sifirlama sonrasi gelir 0")
	_check(SaveService.call("load_game") == true, "kayit okunur")
	_check(UpgradeSystem.is_purchased(&"asteroid_boost"), "upgrade yuklenir")
	_check(Economy.get_orbiter_count(&"asteroid") == 10, "orbiter sayisi yuklenir")
	var income: float = Economy.get_income_per_sec().to_float()
	_check(is_equal_approx(income, 20.0), "YUKLEME SONRASI gelir upgrade'li olmali (20/sn), bulunan: %s" % income)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	if _failed == 0:
		print("Kayit entegrasyon testi: TAMAM")
	else:
		printerr("Kayit entegrasyon testi: %d HATA" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _reset() -> void:
	UpgradeSystem.deserialize({})
	GameState.deserialize({})
	Economy.refresh()


func _check(condition: bool, name: String) -> void:
	if not condition:
		_failed += 1
		printerr("BASARISIZ: ", name)
