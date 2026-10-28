extends Node
## STUB (A0). Gercek implementasyon A3 (#5) ile gelecek.
## Imzalar sozlesmeye (#1) birebir uygun, degerler sabit.
## Autoload adi: Economy (class_name KULLANMA).


## Yildiza tiklama. Kazanilan miktari dondurur (floating text icin).
func click() -> BigNumber:
	return BigNumber.from_float(1.0)


func try_buy_orbiter(_id: StringName) -> bool:
	return false


func try_buy_upgrade(_id: StringName) -> bool:
	return false


func get_orbiter_count(_id: StringName) -> int:
	return 0


func get_orbiter_cost(_id: StringName) -> BigNumber:
	return BigNumber.from_float(10.0)


func get_income_per_sec() -> BigNumber:
	return BigNumber.from_float(0.0)


func get_click_value() -> BigNumber:
	return BigNumber.from_float(1.0)
