extends SceneTree
## BigNumber testleri. Çalıştırma (proje bir kez editörde açılmış / import edilmiş olmalı):
##   godot --headless --path . --script res://tests/big_number_test.gd
## Çıkış kodu: 0 = tamam, 1 = en az bir test başarısız.

const BN := preload("res://core/big_number.gd")

var _failed: int = 0


func _init() -> void:
	_test_normalize()
	_test_add_sub()
	_test_mul()
	_test_mul_pow()
	_test_compare()
	_test_to_string_short()
	_test_conversion_and_save()
	if _failed == 0:
		print("BigNumber testleri: TAMAM")
	else:
		printerr("BigNumber testleri: %d HATA" % _failed)
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if not condition:
		_failed += 1
		printerr("BASARISIZ: ", name)


func _near(a: float, b: float) -> bool:
	return absf(a - b) <= absf(b) * 1e-9


func _test_normalize() -> void:
	var n = BN.from_float(1234.5)
	_check(_near(n.mantissa, 1.2345) and n.exponent == 3, "normalize 1234.5")
	var s = BN.from_float(0.05)
	_check(_near(s.mantissa, 5.0) and s.exponent == -2, "normalize 0.05")
	var z = BN.from_float(0.0)
	_check(z.mantissa == 0.0 and z.exponent == 0, "normalize 0")
	var p = BN.from_parts(45.0, 2)
	_check(_near(p.mantissa, 4.5) and p.exponent == 3, "from_parts normalize")
	var neg = BN.from_float(-250.0)
	_check(_near(neg.mantissa, -2.5) and neg.exponent == 2, "normalize negatif")


func _test_add_sub() -> void:
	_check(_near(BN.from_float(1000.0).add(BN.from_float(2500.0)).to_float(), 3500.0), "add 1000+2500")
	var big = BN.from_parts(1.0, 20).add(BN.from_parts(1.0, 19))
	_check(_near(big.mantissa, 1.1) and big.exponent == 20, "add 1e20+1e19")
	var huge = BN.from_parts(1.0, 100).add(BN.from_float(5.0))
	_check(huge.mantissa == 1.0 and huge.exponent == 100, "add buyuk+cok kucuk")
	_check(_near(BN.from_float(7.0).add(BN.zero()).to_float(), 7.0), "add sifir")
	_check(_near(BN.from_float(5.0).sub(BN.from_float(3.0)).to_float(), 2.0), "sub 5-3")
	_check(_near(BN.from_float(3.0).sub(BN.from_float(5.0)).to_float(), -2.0), "sub 3-5 negatif")
	_check(BN.from_float(4.0).sub(BN.from_float(4.0)).compare_to(BN.zero()) == 0, "sub esit -> 0")


func _test_mul() -> void:
	var m = BN.from_parts(2.0, 10).mul(BN.from_parts(3.0, 5))
	_check(_near(m.mantissa, 6.0) and m.exponent == 15, "mul 2e10*3e5")
	var r = BN.from_parts(5.0, 3).mul(BN.from_parts(4.0, 3))
	_check(_near(r.mantissa, 2.0) and r.exponent == 7, "mul normalize 5e3*4e3")
	_check(_near(BN.from_float(12.0).mul_float(0.5).to_float(), 6.0), "mul_float")
	_check(BN.from_float(12.0).mul(BN.zero()).mantissa == 0.0, "mul sifir")


func _test_mul_pow() -> void:
	# 15 * 1.15^10 = 60.68336603861...
	var c = BN.from_float(15.0).mul_pow(1.15, 10)
	_check(_near(c.to_float(), 60.683366038611), "mul_pow 15*1.15^10")
	_check(BN.from_float(15.0).mul_pow(1.15, 0).to_float() == 15.0, "mul_pow n=0")
	# Büyük n taşmaz: 1.07^5000 ~ 1e146
	var h = BN.from_float(1.0).mul_pow(1.07, 5000)
	_check(h.exponent > 140 and h.exponent < 150, "mul_pow buyuk n")


func _test_compare() -> void:
	var a = BN.from_float(100.0)
	var b = BN.from_float(200.0)
	_check(b.gt(a) and a.lt(b) and b.gte(a) and a.lte(b), "compare temel")
	_check(a.equals(BN.from_float(100.0)) and a.gte(BN.from_float(100.0)), "compare esit")
	_check(BN.from_parts(1.0, 50).gt(BN.from_parts(9.0, 49)), "compare farkli ussu")
	_check(BN.zero().lt(a) and a.gt(BN.zero()), "compare sifir")
	_check(BN.from_float(-5.0).lt(BN.from_float(-3.0)), "compare negatif ayni us")
	_check(BN.from_float(-500.0).lt(BN.from_float(-5.0)), "compare negatif farkli us")
	_check(BN.from_float(-1.0).lt(BN.zero()) and BN.zero().gt(BN.from_float(-1.0)), "compare negatif-sifir")


func _test_to_string_short() -> void:
	_check(BN.zero().to_string_short() == "0", "str 0")
	_check(BN.from_float(12.5).to_string_short() == "12.5", "str 12.5")
	_check(BN.from_float(999.0).to_string_short() == "999", "str 999")
	_check(BN.from_float(1000.0).to_string_short() == "1K", "str 1000")
	_check(BN.from_float(1234.0).to_string_short() == "1.23K", "str 1234")
	_check(BN.from_float(1500000.0).to_string_short() == "1.5M", "str 1.5M")
	_check(BN.from_float(999999.9).to_string_short() == "1M", "str yuvarlama 999999.9")
	_check(BN.from_parts(2.5, 9).to_string_short() == "2.5B", "str 2.5B")
	_check(BN.from_parts(1.0, 36).to_string_short() == "1e36", "str bilimsel")
	_check(BN.from_float(-1500.0).to_string_short() == "-1.5K", "str negatif")
	_check(BN.from_float(0.05).to_string_short() == "0.05", "str kucuk")


func _test_conversion_and_save() -> void:
	_check(_near(BN.from_float(1500.0).to_float(), 1500.0), "to_float")
	_check(BN.from_parts(1.0, 400).to_float() == INF, "to_float tasma")
	var original = BN.from_parts(3.25, 47)
	var json_text: String = JSON.stringify(original.to_dict())
	var back = BN.from_dict(JSON.parse_string(json_text))
	_check(original.equals(back), "serialize round-trip (JSON)")
	_check(BN.from_dict({}).equals(BN.zero()), "from_dict bos")
