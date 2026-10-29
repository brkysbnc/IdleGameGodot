extends SceneTree
## SaveService testi. GameState/UpgradeSystem gerekmez, sahte provider'larla calisir.
## Gercek save.json'a dokunmaz, user://b3_test_save.json kullanir ve sonunda siler.
## Calistirma (proje kokunden):
##   godot --headless --path . --script res://systems/save/tests/save_service_test.gd
## Basarisiz test varsa cikis kodu 1 olur.

const SaveServiceScript := preload("res://systems/save/save_service.gd")
const TEST_PATH := "user://b3_test_save.json"

var _failures := 0
var _checks := 0


## GameState/UpgradeSystem yerine gecen sahte provider.
class Provider extends RefCounted:
	var data: Dictionary = {}
	var received: Variant = null
	var deserialize_calls := 0

	func _init(p_data: Dictionary = {}) -> void:
		data = p_data

	func serialize() -> Dictionary:
		return data

	func deserialize(p_data: Dictionary) -> void:
		received = p_data
		deserialize_calls += 1


## BigNumber yerine gecen sahte nesne (to_dict'i var).
class FakeBig extends RefCounted:
	func to_dict() -> Dictionary:
		return {"m": 1.5, "e": 42}


func _init() -> void:
	_test_roundtrip()
	_test_no_tmp_left_after_save()
	_test_big_number_like_object()
	_test_non_finite_float_sanitized()
	_test_corrupt_file_starts_clean()
	_test_backup_used_when_main_corrupt()
	_test_newer_version_rejected()
	_test_missing_section_untouched()
	_test_non_dictionary_section_skipped()
	_test_no_file_is_clean_start()
	_test_invalid_provider_rejected()
	_test_post_load_runs_after_all_sections()
	_test_post_load_not_called_on_clean_start()
	_test_offline_payout_triggers_save()
	_cleanup()
	print("SaveService testleri: %d kontrol, %d basarisiz" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _make(state: Object, upgrades: Object) -> Node:
	var service: Node = SaveServiceScript.new()
	service.save_path = TEST_PATH
	service.register_section(&"game_state", state)
	service.register_section(&"upgrades", upgrades)
	return service


func _test_roundtrip() -> void:
	_cleanup()
	var state := Provider.new({"gold": {"m": 1.2345678901234567, "e": 12}, "counts": {"moon": 3}})
	var upgrades := Provider.new({"version": 1, "purchased": ["a", "b"]})
	var writer := _make(state, upgrades)
	_eq(writer.save_game(), true, "kayit basarili")

	var state2 := Provider.new()
	var upgrades2 := Provider.new()
	var reader := _make(state2, upgrades2)
	_eq(reader.load_game(), true, "yukleme basarili")
	var received: Dictionary = state2.received
	_eq(received["gold"]["m"], 1.2345678901234567, "mantissa kayipsiz geri geldi")
	_eq(int(received["gold"]["e"]), 12, "exponent geri geldi")
	_eq(int(received["counts"]["moon"]), 3, "sayac geri geldi")
	_eq((upgrades2.received as Dictionary)["purchased"], ["a", "b"], "upgrade listesi geri geldi")
	writer.free()
	reader.free()


func _test_no_tmp_left_after_save() -> void:
	_cleanup()
	var s := _make(Provider.new({"x": 1}), Provider.new())
	s.save_game()
	_eq(FileAccess.file_exists(TEST_PATH), true, "ana dosya var")
	_eq(FileAccess.file_exists(TEST_PATH + ".tmp"), false, "tmp dosyasi kalmadi")
	s.free()


func _test_big_number_like_object() -> void:
	_cleanup()
	var writer := _make(Provider.new({"gold": FakeBig.new()}), Provider.new())
	writer.save_game()
	var state2 := Provider.new()
	var reader := _make(state2, Provider.new())
	reader.load_game()
	var gold: Dictionary = (state2.received as Dictionary)["gold"]
	_eq(gold["m"], 1.5, "BigNumber benzeri nesne to_dict ile yazildi (m)")
	_eq(int(gold["e"]), 42, "BigNumber benzeri nesne to_dict ile yazildi (e)")
	writer.free()
	reader.free()


func _test_non_finite_float_sanitized() -> void:
	_cleanup()
	var writer := _make(Provider.new({"bad": INF, "worse": NAN}), Provider.new())
	_eq(writer.save_game(), true, "INF/NAN olsa da kayit basarili")
	var state2 := Provider.new()
	var reader := _make(state2, Provider.new())
	_eq(reader.load_game(), true, "INF/NAN'li kayit okunabilir")
	_eq((state2.received as Dictionary)["bad"], 0.0, "INF 0'a cevrildi")
	_eq((state2.received as Dictionary)["worse"], 0.0, "NAN 0'a cevrildi")
	writer.free()
	reader.free()


func _test_corrupt_file_starts_clean() -> void:
	_cleanup()
	_write_raw(TEST_PATH, "{bu json degil ][")
	var state := Provider.new()
	var s := _make(state, Provider.new())
	_eq(s.load_game(), false, "bozuk kayitta temiz baslangic (false)")
	_eq(state.deserialize_calls, 0, "bozuk kayitta deserialize cagrilmadi")
	_eq(FileAccess.file_exists(TEST_PATH.get_basename() + ".corrupt.json"), true, "bozuk kayit kenara alindi")
	_eq(FileAccess.file_exists(TEST_PATH), false, "bozuk kayit ana yoldan kalkti")
	_eq(s.save_game(), true, "temiz baslangictan sonra kayit calisir")
	s.free()


func _test_backup_used_when_main_corrupt() -> void:
	_cleanup()
	var first := Provider.new({"value": 1})
	var s := _make(first, Provider.new())
	s.save_game() # v1
	first.data = {"value": 2}
	s.save_game() # v2, v1 yedege gider
	_eq(FileAccess.file_exists(TEST_PATH + ".bak"), true, "yedek dosya olustu")
	_write_raw(TEST_PATH, "bozuk")

	var state2 := Provider.new()
	var reader := _make(state2, Provider.new())
	_eq(reader.load_game(), true, "ana bozukken yedekten yukleme")
	_eq(int((state2.received as Dictionary)["value"]), 1, "yedekteki onceki kayit geldi")
	s.free()
	reader.free()


func _test_newer_version_rejected() -> void:
	_cleanup()
	_write_raw(TEST_PATH, JSON.stringify({"version": 99, "sections": {"game_state": {"a": 1}}}))
	var state := Provider.new()
	var s := _make(state, Provider.new())
	_eq(s.load_game(), false, "gelecek surum kaydi reddedilir")
	_eq(state.deserialize_calls, 0, "gelecek surumde deserialize cagrilmadi")
	s.free()


func _test_missing_section_untouched() -> void:
	_cleanup()
	_write_raw(TEST_PATH, JSON.stringify({"version": 1, "sections": {"game_state": {"a": 1}}}))
	var state := Provider.new()
	var upgrades := Provider.new()
	var s := _make(state, upgrades)
	_eq(s.load_game(), true, "eksik parcali kayit yuklenir")
	_eq(state.deserialize_calls, 1, "mevcut parca dagitildi")
	_eq(upgrades.deserialize_calls, 0, "eksik parca atlandi (varsayilan kalir)")
	s.free()


func _test_non_dictionary_section_skipped() -> void:
	_cleanup()
	_write_raw(TEST_PATH, JSON.stringify({"version": 1, "sections": {"game_state": [1, 2], "upgrades": {"ok": true}}}))
	var state := Provider.new()
	var upgrades := Provider.new()
	var s := _make(state, upgrades)
	s.load_game()
	_eq(state.deserialize_calls, 0, "sozluk olmayan parca atlandi")
	_eq(upgrades.deserialize_calls, 1, "gecerli parca yine de dagitildi")
	s.free()


func _test_no_file_is_clean_start() -> void:
	_cleanup()
	var state := Provider.new()
	var s := _make(state, Provider.new())
	_eq(s.load_game(), false, "kayit yoksa temiz baslangic")
	_eq(state.deserialize_calls, 0, "kayit yoksa deserialize cagrilmaz")
	s.free()


func _test_invalid_provider_rejected() -> void:
	_cleanup()
	var s: Node = SaveServiceScript.new()
	s.save_path = TEST_PATH
	s.register_section(&"yanlis", RefCounted.new()) # serialize/deserialize yok
	s.register_section(&"game_state", Provider.new({"ok": 1}))
	_eq(s.save_game(), true, "gecersiz provider kaydi bozmaz")
	var state2 := Provider.new()
	var reader := _make(state2, Provider.new())
	reader.load_game()
	_eq(int((state2.received as Dictionary)["ok"]), 1, "gecerli provider yazildi")
	s.free()
	reader.free()


func _test_post_load_runs_after_all_sections() -> void:
	_cleanup()
	var writer := _make(Provider.new({"a": 1}), Provider.new({"b": 2}))
	writer.save_game()

	var order := []
	var state := OrderedProvider.new("state", order)
	var upgrades := OrderedProvider.new("upgrades", order)
	var late := OrderedProvider.new("late", order)
	var reader := _make(state, upgrades)
	reader.register_section(&"late", late) # kayitta yok ama post_load yine de cagrilir
	reader.load_game()
	_eq(order, ["deserialize:state", "deserialize:upgrades", "post_load:state", "post_load:upgrades", "post_load:late"],
		"post_load, tum deserialize'lardan sonra calisir")
	writer.free()
	reader.free()


func _test_post_load_not_called_on_clean_start() -> void:
	_cleanup()
	var order := []
	var s := _make(OrderedProvider.new("state", order), OrderedProvider.new("upgrades", order))
	s.load_game()
	_eq(order.size(), 0, "temiz baslangicta post_load cagrilmaz")
	s.free()


## Offline kazanc verilince SaveService hemen kaydeder (saved_at guncellensin, ayni sure iki kez odenmesin).
func _test_offline_payout_triggers_save() -> void:
	_cleanup()
	var s: Node = SaveServiceScript.new()
	s.save_path = TEST_PATH
	s.register_section(&"game_state", Provider.new({"x": 1}))
	s._register_offline_progress()
	var offline: Node = s.get_child(0) # _register_offline_progress tek cocuk ekler
	offline.setup(
		func() -> float: return 100000.0,
		func() -> FakeNumber: return FakeNumber.new(1.0),
		func(_amount: Variant) -> void: pass
	)
	_eq(FileAccess.file_exists(TEST_PATH), false, "odemeden once kayit yok")
	offline.grant(3600.0)
	_eq(FileAccess.file_exists(TEST_PATH), true, "odemeden sonra otomatik kayit yapildi")
	s.free()


## Gelir icin sahte sayi (mantissa + mul_float).
class FakeNumber extends RefCounted:
	var mantissa: float = 0.0

	func _init(p_value: float = 0.0) -> void:
		mantissa = p_value

	func mul_float(factor: float) -> FakeNumber:
		return FakeNumber.new(mantissa * factor)


## deserialize ve post_load siralarini kaydeden provider.
class OrderedProvider extends RefCounted:
	var _name: String
	var _log: Array

	func _init(p_name: String, p_log: Array) -> void:
		_name = p_name
		_log = p_log

	func serialize() -> Dictionary:
		return {}

	func deserialize(_data: Dictionary) -> void:
		_log.append("deserialize:" + _name)

	func post_load() -> void:
		_log.append("post_load:" + _name)


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	for path in [
		TEST_PATH,
		TEST_PATH + ".tmp",
		TEST_PATH + ".bak",
		TEST_PATH.get_basename() + ".corrupt.json",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("BASARISIZ: %s (beklenen: %s, gelen: %s)" % [label, expected, actual])
