class_name BigNumber
extends RefCounted
## STUB (A0). Gercek implementasyon A1 (#3) ile gelecek.
## Imzalar sabit: B bunlara gore kod yazabilir, A1 ic kismi doldurur.

var mantissa: float = 0.0
var exponent: int = 0


static func from_float(value: float) -> BigNumber:
	var n := BigNumber.new()
	n.mantissa = value
	return n


## "1.2K", "3.4M" gibi kisa gosterim. STUB: duz sayiyi dondurur.
func to_string_short() -> String:
	return str(mantissa)


func to_float() -> float:
	return mantissa * pow(10.0, exponent)
