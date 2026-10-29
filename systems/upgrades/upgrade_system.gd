extends Node
## STUB (A0). Gercek implementasyon B1 (#10) ile gelecek (Bozhan).
## Economy bu carpanlari okur. Stub'da hepsi nötr (1.0 / 0.0).
## Autoload adi: UpgradeSystem (class_name KULLANMA).


func get_click_multiplier() -> float:
	return 1.0


func get_global_multiplier() -> float:
	return 1.0


func get_orbiters_multiplier() -> float:
	return 1.0


func get_orbiter_multiplier(_id: StringName) -> float:
	return 1.0


## Saniyede otomatik tik sayisi.
func get_auto_click_rate() -> float:
	return 0.0


## Economy satin almayi onaylayinca cagirir.
func apply_upgrade(_id: StringName) -> void:
	pass


func is_purchased(_id: StringName) -> bool:
	return false


## Kayit arayuzu (SaveService kullanir).
func serialize() -> Dictionary:
	return {}


func deserialize(_data: Dictionary) -> void:
	pass
