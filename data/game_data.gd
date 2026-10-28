class_name GameData
extends RefCounted
## Orbiter ve upgrade kataloğu (A4): klasörlerdeki .tres dosyalarını bir kez yükler, önbellekler.
## Economy, mağaza paneli ve testler buradan okur (tek yükleme noktası, DRY).
## Autoload değil: static önbellek, project.godot'a dokunmaz.

const ORBITERS_DIR := "res://data/orbiters"
const UPGRADES_DIR := "res://data/upgrades"

static var _loaded: bool = false
static var _orbiters: Array[OrbiterData] = []
static var _upgrades: Array[UpgradeData] = []
static var _orbiters_by_id: Dictionary = {} # StringName -> OrbiterData
static var _upgrades_by_id: Dictionary = {} # StringName -> UpgradeData


## Maliyete göre artan sırada (listeler hep bu sırada gösterilir).
static func orbiters() -> Array[OrbiterData]:
	_ensure_loaded()
	return _orbiters


## Maliyete göre artan sırada.
static func upgrades() -> Array[UpgradeData]:
	_ensure_loaded()
	return _upgrades


static func get_orbiter(id: StringName) -> OrbiterData:
	_ensure_loaded()
	return _orbiters_by_id.get(id)


static func get_upgrade(id: StringName) -> UpgradeData:
	_ensure_loaded()
	return _upgrades_by_id.get(id)


## Mağaza panelinin Upgrades listesi: orbiter'a özel olmayanlar.
static func general_upgrades() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade in upgrades():
		if not upgrade.is_orbiter_upgrade():
			result.append(upgrade)
	return result


## Orbiter Upgrade menüsü: belirli bir orbiter'a özel upgrade'ler.
static func upgrades_for_orbiter(orbiter_id: StringName) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade in upgrades():
		if upgrade.is_orbiter_upgrade() and upgrade.target_orbiter_id == orbiter_id:
			result.append(upgrade)
	return result


## Test için: önbelleği temizler, bir sonraki erişimde yeniden yükler.
static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_orbiters.clear()
	_upgrades.clear()
	_orbiters_by_id.clear()
	_upgrades_by_id.clear()
	for resource in _load_dir(ORBITERS_DIR):
		var orbiter := resource as OrbiterData
		if orbiter == null:
			continue
		if _orbiters_by_id.has(orbiter.id):
			push_warning("GameData: orbiter '%s' birden fazla tanimlanmis, ilki kullanildi." % orbiter.id)
			continue
		_orbiters_by_id[orbiter.id] = orbiter
		_orbiters.append(orbiter)
	for resource in _load_dir(UPGRADES_DIR):
		var upgrade := resource as UpgradeData
		if upgrade == null:
			continue
		if _upgrades_by_id.has(upgrade.id):
			push_warning("GameData: upgrade '%s' birden fazla tanimlanmis, ilki kullanildi." % upgrade.id)
			continue
		_upgrades_by_id[upgrade.id] = upgrade
		_upgrades.append(upgrade)
	_orbiters.sort_custom(func(a: OrbiterData, b: OrbiterData) -> bool: return a.base_cost < b.base_cost)
	_upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.cost < b.cost)
	_loaded = true


## Klasördeki tüm .tres dosyalarını yükler (export'ta .remap uzantılı olanlar dahil).
static func _load_dir(dir_path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("GameData: '%s' klasoru acilamadi." % dir_path)
		return result
	var names := dir.get_files()
	names.sort() # kararli sira
	for file_name in names:
		var clean_name := file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var resource := load(dir_path.path_join(clean_name))
		if resource == null:
			push_warning("GameData: '%s' yuklenemedi." % clean_name)
			continue
		result.append(resource)
	return result
