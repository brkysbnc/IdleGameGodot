class_name UpgradeData
extends Resource
## Bir upgrade'in verisi (A4). Yeni upgrade = data/upgrades/ altına yeni .tres, kod değişmez.
## UpgradeSystem (Bozhan, B1) bu alanları okur: id, type, target_orbiter_id, value.

const TYPE_AUTO_CLICK := &"auto_click"
const TYPE_PER_CLICK := &"per_click"
const TYPE_ALL_INCOME := &"all_income"
const TYPE_ALL_ORBITERS := &"all_orbiters"
const TYPE_ORBITER := &"orbiter"

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## auto_click: saniyedeki otomatik tık eklenir. per_click / all_income / all_orbiters / orbiter: çarpan.
@export_enum("auto_click", "per_click", "all_income", "all_orbiters", "orbiter") var type: String = "per_click"
## Sadece type == "orbiter" için: etkilenen orbiter'ın OrbiterData.id değeri.
@export var target_orbiter_id: StringName
## Tek seferlik satın alma maliyeti.
@export var cost: float = 100.0
## auto_click için tık/sn, diğerleri için çarpan (örn. 2.0 = iki katı).
@export var value: float = 2.0


func is_orbiter_upgrade() -> bool:
	return type == TYPE_ORBITER
