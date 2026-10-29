extends SceneTree
## B6 testi: game/visuals/ icindeki her .tres gecerli mi, id'ler benzersiz mi, yorunge bantlari cakisiyor mu,
## ve (data/orbiters/ varsa) A'nin orbiter id'leriyle birebir eslesiyor mu.
## Autoload gerekmez. Calistirma (proje kokunden):
##   godot --headless --path . --script res://game/tests/orbiter_visual_data_test.gd
## Basarisiz test varsa cikis kodu 1 olur.

const VisualScript := preload("res://game/visuals/orbiter_visual_data.gd")
const VISUALS_DIR := "res://game/visuals"
const ORBITERS_DIR := "res://data/orbiters"

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	var visuals: Array = _load_visuals()
	_check(visuals.size() > 0, "en az bir gorsel .tres yuklendi")
	_test_each_is_valid(visuals)
	_test_ids_unique(visuals)
	_test_bands_do_not_overlap(visuals)
	_test_matches_data_orbiters(visuals)
	_test_validate_catches_bad_data()
	print("OrbiterVisualData testleri: %d kontrol, %d basarisiz" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _load_visuals() -> Array:
	var result: Array = []
	var dir: DirAccess = DirAccess.open(VISUALS_DIR)
	if dir == null:
		return result
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		var clean_name: String = file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var resource: Resource = load(VISUALS_DIR.path_join(clean_name))
		_check(resource != null, "%s yuklenir" % clean_name)
		if resource == null:
			continue
		_check(resource.get_script() == VisualScript, "%s OrbiterVisualData script'ine bagli" % clean_name)
		if resource.get_script() == VisualScript:
			result.append(resource)
	return result


func _test_each_is_valid(visuals: Array) -> void:
	for visual: Resource in visuals:
		var problems: PackedStringArray = visual.call("validate")
		_check(problems.is_empty(), "%s gecerli (%s)" % [visual.get("orbiter_id"), ", ".join(problems)])


func _test_ids_unique(visuals: Array) -> void:
	var seen: Dictionary = {}
	for visual: Resource in visuals:
		var id: StringName = visual.get("orbiter_id")
		_check(not seen.has(id), "id benzersiz: %s" % id)
		seen[id] = true


## Turlerin bantlari ic ice girmesin (gorsel olarak ayirt edilebilsinler).
func _test_bands_do_not_overlap(visuals: Array) -> void:
	var sorted_visuals: Array = visuals.duplicate()
	sorted_visuals.sort_custom(_by_radius)
	for i: int in range(1, sorted_visuals.size()):
		var inner: Resource = sorted_visuals[i - 1]
		var outer: Resource = sorted_visuals[i]
		var inner_edge: float = float(inner.get("orbit_radius")) + float(inner.get("orbit_spread")) * 0.5
		var outer_edge: float = float(outer.get("orbit_radius")) - float(outer.get("orbit_spread")) * 0.5
		_check(inner_edge < outer_edge, "bantlar cakismiyor: %s / %s" % [inner.get("orbiter_id"), outer.get("orbiter_id")])


func _by_radius(a: Resource, b: Resource) -> bool:
	return float(a.get("orbit_radius")) < float(b.get("orbit_radius"))


## A'nin data/orbiters/ klasoru yoksa (B dali henuz onunla birlesmediyse) atlanir.
## .tres'ler metin olarak okunur, OrbiterData sinifina ihtiyac yok.
func _test_matches_data_orbiters(visuals: Array) -> void:
	var data_ids: Dictionary = _read_orbiter_ids()
	if data_ids.is_empty():
		print("ATLANDI: data/orbiters/ bulunamadi, gorsel-ekonomi id eslesmesi kontrol edilmedi.")
		return
	var visual_ids: Dictionary = {}
	for visual: Resource in visuals:
		visual_ids[visual.get("orbiter_id")] = true
	for id: StringName in data_ids:
		_check(visual_ids.has(id), "orbiter '%s' icin gorsel .tres var" % id)
	for id: StringName in visual_ids:
		_check(data_ids.has(id), "gorsel '%s' icin data/orbiters'ta orbiter var" % id)


func _read_orbiter_ids() -> Dictionary:
	var ids: Dictionary = {}
	var dir: DirAccess = DirAccess.open(ORBITERS_DIR)
	if dir == null:
		return ids
	var regex: RegEx = RegEx.create_from_string("(?m)^id\\s*=\\s*&\"([^\"]+)\"")
	for file_name: String in dir.get_files():
		var clean_name: String = file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var file: FileAccess = FileAccess.open(ORBITERS_DIR.path_join(clean_name), FileAccess.READ)
		if file == null:
			continue
		var found: RegExMatch = regex.search(file.get_as_text())
		if found != null:
			ids[StringName(found.get_string(1))] = true
	return ids


func _test_validate_catches_bad_data() -> void:
	var bad: Resource = VisualScript.new()
	_check(not (bad.call("validate") as PackedStringArray).is_empty(), "bos id gecersiz sayilir")
	bad.set("orbiter_id", &"x")
	bad.set("orbit_radius", 4.0)
	bad.set("orbit_spread", 10.0)
	_check(not (bad.call("validate") as PackedStringArray).is_empty(), "yildizin icine giren bant gecersiz sayilir")
	bad.set("orbit_spread", 2.0)
	_check((bad.call("validate") as PackedStringArray).is_empty(), "duzeltilince gecerli")
	_check(is_equal_approx(float(bad.call("get_extent")), 4.0 + 1.0 + 0.3), "get_extent = radius + spread/2 + size")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("BASARISIZ: %s" % label)
