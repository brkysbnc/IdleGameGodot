extends SceneTree
## data/ içeriğinin tutarlılık testi (A4). Çalıştırma:
##   godot --headless --path . --script res://tests/game_data_test.gd
## Çıkış kodu: 0 = tamam, 1 = hata. Yeni .tres eklenince otomatik kapsanır.

const VALID_TYPES := ["auto_click", "per_click", "all_income", "all_orbiters", "orbiter"]

var _failed: int = 0


func _init() -> void:
	GameData.reload()
	_test_orbiters()
	_test_upgrades()
	_test_queries()
	if _failed == 0:
		print("GameData testleri: TAMAM (%d orbiter, %d upgrade)" % [GameData.orbiters().size(), GameData.upgrades().size()])
	else:
		printerr("GameData testleri: %d HATA" % _failed)
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if not condition:
		_failed += 1
		printerr("BASARISIZ: ", name)


func _test_orbiters() -> void:
	var orbiters := GameData.orbiters()
	_check(orbiters.size() >= 5, "en az 5 orbiter yuklenmeli")
	var seen := {}
	var previous_cost := 0.0
	for orbiter in orbiters:
		_check(orbiter.id != &"", "orbiter id bos olmamali")
		_check(not seen.has(orbiter.id), "orbiter id benzersiz: %s" % orbiter.id)
		seen[orbiter.id] = true
		_check(orbiter.base_cost > 0.0, "base_cost > 0: %s" % orbiter.id)
		_check(orbiter.cost_growth > 1.0, "cost_growth > 1: %s" % orbiter.id)
		_check(orbiter.base_income > 0.0, "base_income > 0: %s" % orbiter.id)
		_check(orbiter.base_cost >= previous_cost, "orbiter listesi maliyete gore sirali: %s" % orbiter.id)
		previous_cost = orbiter.base_cost


func _test_upgrades() -> void:
	var seen := {}
	var previous_cost := 0.0
	for upgrade in GameData.upgrades():
		_check(upgrade.id != &"", "upgrade id bos olmamali")
		_check(not seen.has(upgrade.id), "upgrade id benzersiz: %s" % upgrade.id)
		seen[upgrade.id] = true
		_check(VALID_TYPES.has(upgrade.type), "gecerli type: %s (%s)" % [upgrade.id, upgrade.type])
		_check(upgrade.cost > 0.0 and upgrade.value > 0.0, "cost ve value > 0: %s" % upgrade.id)
		_check(upgrade.cost >= previous_cost, "upgrade listesi maliyete gore sirali: %s" % upgrade.id)
		previous_cost = upgrade.cost
		if upgrade.is_orbiter_upgrade():
			_check(GameData.get_orbiter(upgrade.target_orbiter_id) != null, "orbiter upgrade hedefi mevcut: %s -> %s" % [upgrade.id, upgrade.target_orbiter_id])
		else:
			_check(upgrade.target_orbiter_id == &"", "genel upgrade'in hedefi bos olmali: %s" % upgrade.id)


func _test_queries() -> void:
	_check(GameData.get_orbiter(&"moon") != null, "get_orbiter(moon)")
	_check(GameData.get_orbiter(&"yok") == null, "get_orbiter bilinmeyen -> null")
	_check(GameData.get_upgrade(&"click_power_1") != null, "get_upgrade(click_power_1)")
	var general := GameData.general_upgrades()
	for upgrade in general:
		_check(not upgrade.is_orbiter_upgrade(), "general_upgrades orbiter'a ozel icermemeli")
	var for_moon := GameData.upgrades_for_orbiter(&"moon")
	_check(for_moon.size() >= 1, "ay icin en az bir orbiter upgrade'i")
	for upgrade in for_moon:
		_check(upgrade.target_orbiter_id == &"moon", "upgrades_for_orbiter dogru hedef")
