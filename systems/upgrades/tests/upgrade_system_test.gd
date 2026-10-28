extends SceneTree
## UpgradeSystem testi. A3/A4 gerekmez, sahte tanimlarla calisir.
## Calistirma (proje kokunden):
##   godot --headless --path . --script res://systems/upgrades/tests/upgrade_system_test.gd
## Basarisiz test varsa cikis kodu 1 olur.

const UpgradeSystemScript := preload("res://systems/upgrades/upgrade_system.gd")

var _failures := 0
var _checks := 0


## UpgradeData (A4) yerine gecen sahte tanim. Ayni alan adlari.
class FakeUpgrade extends RefCounted:
	var id: StringName
	var type: Variant
	var target_orbiter_id: StringName = &""
	var value: float = 1.0

	func _init(p_id: StringName, p_type: Variant, p_value: float, p_target: StringName = &"") -> void:
		id = p_id
		type = p_type
		value = p_value
		target_orbiter_id = p_target


func _init() -> void:
	_test_defaults()
	_test_each_type()
	_test_stacking()
	_test_orbiter_isolation()
	_test_double_purchase_ignored()
	_test_unknown_id_ignored()
	_test_enum_type_support()
	_test_serialize_roundtrip()
	_test_deserialize_skips_unknown_and_resets()
	print("UpgradeSystem testleri: %d kontrol, %d basarisiz" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _make() -> Node:
	var system: Node = UpgradeSystemScript.new()
	system.register_definitions([
		FakeUpgrade.new(&"auto_1", &"auto_click", 1.0),
		FakeUpgrade.new(&"auto_2", &"auto_click", 2.5),
		FakeUpgrade.new(&"click_1", &"per_click", 2.0),
		FakeUpgrade.new(&"click_2", &"per_click", 3.0),
		FakeUpgrade.new(&"income_1", &"all_income", 1.5),
		FakeUpgrade.new(&"orbiters_1", &"all_orbiters", 2.0),
		FakeUpgrade.new(&"asteroid_1", &"orbiter", 4.0, &"asteroid"),
		FakeUpgrade.new(&"asteroid_2", &"orbiter", 2.0, &"asteroid"),
		FakeUpgrade.new(&"planet_1", &"orbiter", 3.0, &"planet"),
	])
	return system


func _test_defaults() -> void:
	var s := _make()
	_eq(s.get_click_multiplier(), 1.0, "varsayilan click carpani")
	_eq(s.get_global_multiplier(), 1.0, "varsayilan global carpan")
	_eq(s.get_orbiters_multiplier(), 1.0, "varsayilan orbiters carpani")
	_eq(s.get_orbiter_multiplier(&"planet"), 1.0, "varsayilan orbiter carpani")
	_eq(s.get_auto_click_rate(), 0.0, "varsayilan auto click")
	_eq(s.is_purchased(&"click_1"), false, "varsayilan is_purchased")
	s.free()


func _test_each_type() -> void:
	var s := _make()
	s.apply_upgrade(&"auto_1")
	_eq(s.get_auto_click_rate(), 1.0, "auto_click tipi")
	s.apply_upgrade(&"click_1")
	_eq(s.get_click_multiplier(), 2.0, "per_click tipi")
	s.apply_upgrade(&"income_1")
	_eq(s.get_global_multiplier(), 1.5, "all_income tipi")
	s.apply_upgrade(&"orbiters_1")
	_eq(s.get_orbiters_multiplier(), 2.0, "all_orbiters tipi")
	s.apply_upgrade(&"asteroid_1")
	_eq(s.get_orbiter_multiplier(&"asteroid"), 4.0, "orbiter tipi")
	_eq(s.is_purchased(&"asteroid_1"), true, "is_purchased alindiktan sonra")
	s.free()


func _test_stacking() -> void:
	var s := _make()
	s.apply_upgrade(&"auto_1")
	s.apply_upgrade(&"auto_2")
	_eq(s.get_auto_click_rate(), 3.5, "auto_click toplanir")
	s.apply_upgrade(&"click_1")
	s.apply_upgrade(&"click_2")
	_eq(s.get_click_multiplier(), 6.0, "per_click carpilir")
	s.free()


func _test_orbiter_isolation() -> void:
	var s := _make()
	s.apply_upgrade(&"asteroid_1")
	s.apply_upgrade(&"asteroid_2")
	s.apply_upgrade(&"planet_1")
	_eq(s.get_orbiter_multiplier(&"asteroid"), 8.0, "ayni orbiter upgrade'leri carpilir")
	_eq(s.get_orbiter_multiplier(&"planet"), 3.0, "baska orbiter etkilenmez")
	_eq(s.get_orbiter_multiplier(&"moon"), 1.0, "upgrade'siz orbiter 1.0")
	s.free()


func _test_double_purchase_ignored() -> void:
	var s := _make()
	s.apply_upgrade(&"click_1")
	s.apply_upgrade(&"click_1")
	_eq(s.get_click_multiplier(), 2.0, "ayni upgrade iki kez uygulanmaz")
	s.free()


func _test_unknown_id_ignored() -> void:
	var s := _make()
	s.apply_upgrade(&"yok_boyle_bir_sey")
	_eq(s.is_purchased(&"yok_boyle_bir_sey"), false, "bilinmeyen id alinmis sayilmaz")
	_eq(s.get_click_multiplier(), 1.0, "bilinmeyen id carpani bozmaz")
	s.free()


func _test_enum_type_support() -> void:
	# A4 type'i enum (int) yaparsa: sira #6'daki liste sirasi (0 = auto_click ... 4 = orbiter).
	var s: Node = UpgradeSystemScript.new()
	s.register_definitions([
		FakeUpgrade.new(&"e_auto", 0, 2.0),
		FakeUpgrade.new(&"e_click", 1, 5.0),
		FakeUpgrade.new(&"e_orbiter", 4, 3.0, &"moon"),
	])
	s.apply_upgrade(&"e_auto")
	s.apply_upgrade(&"e_click")
	s.apply_upgrade(&"e_orbiter")
	_eq(s.get_auto_click_rate(), 2.0, "enum: auto_click")
	_eq(s.get_click_multiplier(), 5.0, "enum: per_click")
	_eq(s.get_orbiter_multiplier(&"moon"), 3.0, "enum: orbiter")
	s.free()


func _test_serialize_roundtrip() -> void:
	var a := _make()
	a.apply_upgrade(&"auto_1")
	a.apply_upgrade(&"click_2")
	a.apply_upgrade(&"asteroid_1")
	var data: Dictionary = a.serialize()

	# JSON'dan gecmis gibi davran (SaveService user://save.json kullanir).
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	var b := _make()
	b.deserialize(parsed as Dictionary)

	_eq(b.get_auto_click_rate(), a.get_auto_click_rate(), "roundtrip: auto click")
	_eq(b.get_click_multiplier(), a.get_click_multiplier(), "roundtrip: click carpani")
	_eq(b.get_orbiter_multiplier(&"asteroid"), a.get_orbiter_multiplier(&"asteroid"), "roundtrip: orbiter carpani")
	_eq(b.is_purchased(&"click_2"), true, "roundtrip: is_purchased")
	_eq(b.is_purchased(&"click_1"), false, "roundtrip: alinmayan alinmis cikmaz")
	_eq(data.get("version"), 1, "serialize versiyon alani")
	a.free()
	b.free()


func _test_deserialize_skips_unknown_and_resets() -> void:
	var s := _make()
	s.apply_upgrade(&"click_1") # deserialize onceki durumu silmeli
	s.deserialize({"version": 1, "purchased": ["income_1", "icerikten_silinmis"]})
	_eq(s.is_purchased(&"click_1"), false, "deserialize onceki durumu sifirlar")
	_eq(s.get_click_multiplier(), 1.0, "deserialize onbellegi sifirlar")
	_eq(s.get_global_multiplier(), 1.5, "deserialize gecerli upgrade'i uygular")
	_eq(s.is_purchased(&"icerikten_silinmis"), false, "bilinmeyen kayitli id atlanir")
	s.deserialize({})
	_eq(s.get_global_multiplier(), 1.0, "bos kayit her seyi sifirlar")
	s.free()


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	var same := is_equal_approx(actual, expected) if actual is float and expected is float else actual == expected
	if not same:
		_failures += 1
		printerr("BASARISIZ: %s (beklenen: %s, gelen: %s)" % [label, expected, actual])
