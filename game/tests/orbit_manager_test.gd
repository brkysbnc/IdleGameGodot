extends SceneTree
## B5 testi: OrbitManager sayim, kapasite ve "orbiter basina node yok" garantileri.
## Autoload ve sahne agaci gerekmez (setup/set_count/step dogrudan cagrilir).
## Calistirma (proje kokunden):
##   godot --headless --path . --script res://game/tests/orbit_manager_test.gd
## Basarisiz test varsa cikis kodu 1 olur.

const ManagerScript := preload("res://game/orbit_manager.gd")
const VisualScript := preload("res://game/visuals/orbiter_visual_data.gd")

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_test_nothing_owned_means_no_processing()
	_test_counts_and_capacity_growth()
	_test_draw_cap_limits_visible_but_not_owned()
	_test_decrease_keeps_capacity()
	_test_negative_and_unknown_are_safe()
	_test_one_node_per_type_not_per_orbiter()
	_test_positions_move_and_stay_in_band()
	_test_invalid_and_duplicate_visuals_skipped()
	print("OrbitManager testleri: %d kontrol, %d basarisiz" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _visual(id: StringName, radius: float, spread: float, max_count: int) -> Resource:
	var visual: Resource = VisualScript.new()
	visual.set("orbiter_id", id)
	visual.set("orbit_radius", radius)
	visual.set("orbit_spread", spread)
	visual.set("angular_speed", 0.5)
	visual.set("size", 0.3)
	visual.set("max_instances", max_count)
	return visual


func _manager() -> Node3D:
	var manager: Node3D = ManagerScript.new()
	manager.call("setup", [_visual(&"moon", 12.0, 2.0, 100), _visual(&"planet", 20.0, 3.0, 5)])
	return manager


func _test_nothing_owned_means_no_processing() -> void:
	var m: Node3D = _manager()
	_check(m.call("get_total_visible") == 0, "baslangicta cizilen yok")
	_check(not m.is_processing(), "hic orbiter yokken _process kapali")
	m.free()


func _test_counts_and_capacity_growth() -> void:
	var m: Node3D = _manager()
	m.call("set_count", &"moon", 5)
	_check(m.call("get_visible_count", &"moon") == 5, "5 sahip -> 5 cizilir")
	_check(m.call("get_capacity", &"moon") == 16, "kapasite ilk seferde 16")
	_check(m.is_processing(), "orbiter varken _process acik")
	m.call("set_count", &"moon", 17)
	_check(m.call("get_visible_count", &"moon") == 17, "17 cizilir")
	_check(m.call("get_capacity", &"moon") == 32, "kapasite 2 katina cikti")
	m.free()


func _test_draw_cap_limits_visible_but_not_owned() -> void:
	var m: Node3D = _manager()
	m.call("set_count", &"moon", 1000)
	_check(m.call("get_visible_count", &"moon") == 100, "cizim siniri 100")
	_check(m.call("get_owned_count", &"moon") == 1000, "sahip olunan gercek sayi 1000 kalir (gelir etkilenmez)")
	_check(m.call("get_capacity", &"moon") == 100, "kapasite siniri asmaz")
	m.call("set_count", &"planet", 50)
	_check(m.call("get_visible_count", &"planet") == 5, "baska turun siniri kendi .tres'inden (5)")
	_check(m.call("get_total_visible") == 105, "toplam cizilen = 100 + 5")
	m.free()


func _test_decrease_keeps_capacity() -> void:
	var m: Node3D = _manager()
	m.call("set_count", &"moon", 40)
	var capacity: int = m.call("get_capacity", &"moon")
	m.call("set_count", &"moon", 3)
	_check(m.call("get_visible_count", &"moon") == 3, "azalinca cizilen azalir")
	_check(m.call("get_capacity", &"moon") == capacity, "kapasite kuculmez (yeniden allocation yok)")
	m.call("set_count", &"moon", 0)
	_check(not m.is_processing(), "hepsi 0 olunca _process tekrar kapanir")
	m.free()


func _test_negative_and_unknown_are_safe() -> void:
	var m: Node3D = _manager()
	m.call("set_count", &"moon", -4)
	_check(m.call("get_owned_count", &"moon") == 0 and m.call("get_visible_count", &"moon") == 0, "negatif sayi 0'a sabitlenir")
	m.call("set_count", &"yok_boyle_bir_tur", 10)
	_check(m.call("get_visible_count", &"yok_boyle_bir_tur") == 0, "gorseli olmayan tur cokertmez")
	_check(m.call("get_instance_position", &"yok_boyle_bir_tur", 0) == Vector3.ZERO, "bilinmeyen tur konumu sifir")
	m.free()


## Performans garantisi: orbiter sayisi artinca node sayisi artmaz.
func _test_one_node_per_type_not_per_orbiter() -> void:
	var m: Node3D = _manager()
	_check(m.get_child_count() == 2, "2 tur -> 2 MultiMeshInstance3D")
	m.call("set_count", &"moon", 100)
	m.call("set_count", &"planet", 5)
	_check(m.get_child_count() == 2, "105 orbiter'dan sonra hala 2 node")
	var all_multimesh: bool = true
	for child: Node in m.get_children():
		if not child is MultiMeshInstance3D:
			all_multimesh = false
	_check(all_multimesh, "cocuklarin hepsi MultiMeshInstance3D")
	m.free()


func _test_positions_move_and_stay_in_band() -> void:
	var m: Node3D = _manager()
	m.call("set_count", &"moon", 6)
	var before: Vector3 = m.call("get_instance_position", &"moon", 0)
	m.call("step", 1.0)
	var after: Vector3 = m.call("get_instance_position", &"moon", 0)
	_check(before.distance_to(after) > 0.1, "step sonrasi orbiter yer degistirdi")
	var in_band: bool = true
	for i: int in 6:
		var length: float = (m.call("get_instance_position", &"moon", i) as Vector3).length()
		if length < 11.0 - 0.01 or length > 13.0 + 0.01:
			in_band = false
	_check(in_band, "tum orbiter'lar [11, 13] bandinda")
	_check(m.call("get_instance_position", &"moon", 6) == Vector3.ZERO, "cizilmeyen indeksin konumu sifir")
	m.free()


func _test_invalid_and_duplicate_visuals_skipped() -> void:
	var manager: Node3D = ManagerScript.new()
	var bad: Resource = _visual(&"bad", 0.0, 0.0, 10) # yaricap 0: gecersiz
	var first: Resource = _visual(&"dup", 10.0, 1.0, 10)
	var second: Resource = _visual(&"dup", 30.0, 1.0, 10)
	manager.call("setup", [bad, first, second])
	manager.call("set_count", &"bad", 5)
	_check(manager.call("get_visible_count", &"bad") == 0, "gecersiz gorsel atlandi")
	_check(manager.get_child_count() == 1, "sadece gecerli ve ilk 'dup' kuruldu")
	manager.call("set_count", &"dup", 1)
	var length: float = (manager.call("get_instance_position", &"dup", 0) as Vector3).length()
	_check(length < 12.0, "ilk tanim kullanildi (yaricap ~10, ikincisi 30 olurdu)")
	manager.free()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("BASARISIZ: %s" % label)
