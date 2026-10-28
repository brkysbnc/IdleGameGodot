class_name BigNumber
extends RefCounted
## Çok büyük sayılar için (idle oyunlarda `float` sınırı aşılır): mantissa x 10^exponent.
##
## - Normalize form: 1 <= |mantissa| < 10 (sıfır için mantissa = 0, exponent = 0).
## - DEĞİŞMEZ (immutable): işlemler yeni nesne döner, mevcut nesne değişmez.
##   Bu yüzden sonuçlar güvenle paylaşılır. `mantissa`/`exponent` alanlarını dışarıdan DEĞİŞTİRME.
## - Hassasiyet `float` (çift kesinlik) kadardır, sınırsız hassasiyet hedeflenmez.

const _LN10: float = 2.302585092994046
## İki sayının üs farkı bundan büyükse küçük olan toplamda etkisizdir (double ~15-16 hane).
const _PRECISION_GAP: int = 15
const _SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

var mantissa: float = 0.0
var exponent: int = 0


# --- Oluşturma ---------------------------------------------------------------

static func zero() -> BigNumber:
	return BigNumber.new()


static func from_float(value: float) -> BigNumber:
	return from_parts(value, 0)


## mantissa x 10^exponent değerini normalize ederek oluşturur.
static func from_parts(m: float, e: int) -> BigNumber:
	var n := BigNumber.new()
	n.mantissa = m
	n.exponent = e
	n._normalize()
	return n


# --- Aritmetik ---------------------------------------------------------------

func add(other: BigNumber) -> BigNumber:
	if other.mantissa == 0.0:
		return self
	if mantissa == 0.0:
		return other
	var d: int = exponent - other.exponent
	if d >= _PRECISION_GAP:
		return self
	if d <= -_PRECISION_GAP:
		return other
	if d >= 0:
		return from_parts(mantissa + other.mantissa * pow(10.0, -d), exponent)
	return from_parts(mantissa * pow(10.0, d) + other.mantissa, other.exponent)


func sub(other: BigNumber) -> BigNumber:
	return add(other.negated())


func negated() -> BigNumber:
	var n := BigNumber.new()
	n.mantissa = -mantissa
	n.exponent = exponent
	return n


func mul(other: BigNumber) -> BigNumber:
	return from_parts(mantissa * other.mantissa, exponent + other.exponent)


func mul_float(factor: float) -> BigNumber:
	return from_parts(mantissa * factor, exponent)


## this x growth^n. Maliyet eğrisi (base_cost * growth^owned) için; büyük n'de taşmaz.
## growth > 0 olmalıdır.
func mul_pow(growth: float, n: int) -> BigNumber:
	if mantissa == 0.0 or n == 0:
		return self
	if growth <= 0.0:
		push_error("BigNumber.mul_pow: growth > 0 olmali (verilen: %s)" % growth)
		return BigNumber.zero()
	var shift: float = float(n) * log(growth) / _LN10
	var whole: float = floorf(shift)
	return from_parts(mantissa * pow(10.0, shift - whole), exponent + int(whole))


# --- Karşılaştırma -----------------------------------------------------------

## -1 (küçük), 0 (eşit), 1 (büyük)
func compare_to(other: BigNumber) -> int:
	var sa: float = signf(mantissa)
	var sb: float = signf(other.mantissa)
	if sa != sb:
		return 1 if sa > sb else -1
	if sa == 0.0:
		return 0
	if exponent != other.exponent:
		var c: int = 1 if exponent > other.exponent else -1
		return c if sa > 0.0 else -c
	if mantissa == other.mantissa:
		return 0
	return 1 if mantissa > other.mantissa else -1


func gt(other: BigNumber) -> bool:
	return compare_to(other) > 0


func gte(other: BigNumber) -> bool:
	return compare_to(other) >= 0


func lt(other: BigNumber) -> bool:
	return compare_to(other) < 0


func lte(other: BigNumber) -> bool:
	return compare_to(other) <= 0


func equals(other: BigNumber) -> bool:
	return compare_to(other) == 0


# --- Dönüşüm / gösterim ------------------------------------------------------

## Çok büyükse INF döner (exponent > 308).
func to_float() -> float:
	if exponent > 308:
		return INF * signf(mantissa)
	return mantissa * pow(10.0, exponent)


## "12.5", "1.23K", "4.5M", ... Dc'den sonrası "1.2e45". En fazla 2 ondalık.
## Her çağrıda yeni String üretir; değer değişmedikçe çağıran tarafta önbelleğe alın.
func to_string_short() -> String:
	if mantissa == 0.0:
		return "0"
	var sign_str: String = "-" if mantissa < 0.0 else ""
	var abs_m: float = absf(mantissa)
	if exponent < 0:
		return sign_str + _fmt(abs_m * pow(10.0, exponent))
	var rem: int = exponent % 3
	@warning_ignore("integer_division")
	var group: int = (exponent - rem) / 3
	var scaled: float = snappedf(abs_m * pow(10.0, rem), 0.01)
	if scaled >= 1000.0:
		scaled /= 1000.0
		group += 1
	if group >= _SUFFIXES.size():
		return sign_str + _fmt(abs_m) + "e" + str(exponent)
	return sign_str + _fmt(scaled) + _SUFFIXES[group]


# --- Kayıt (SaveService) -----------------------------------------------------

func to_dict() -> Dictionary:
	return {"m": mantissa, "e": exponent}


## JSON'dan okununca sayılar float gelir, exponent bu yüzden int'e çevrilir.
static func from_dict(data: Dictionary) -> BigNumber:
	return from_parts(float(data.get("m", 0.0)), int(data.get("e", 0)))


# --- İç ----------------------------------------------------------------------

func _normalize() -> void:
	if mantissa == 0.0:
		exponent = 0
		return
	if not is_finite(mantissa):
		push_error("BigNumber: sonlu olmayan deger (NaN/INF), sifira cekildi")
		mantissa = 0.0
		exponent = 0
		return
	var shift: int = floori(log(absf(mantissa)) / _LN10)
	mantissa /= pow(10.0, shift)
	exponent += shift
	# Kayan nokta hatası yüzünden 9.9999.. / 10.0000.. ya da 0.9999.. çıkabilir.
	var a: float = absf(mantissa)
	if a >= 10.0:
		mantissa /= 10.0
		exponent += 1
	elif a < 1.0:
		mantissa *= 10.0
		exponent -= 1


static func _fmt(value: float) -> String:
	var s: String = "%.2f" % value
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s
