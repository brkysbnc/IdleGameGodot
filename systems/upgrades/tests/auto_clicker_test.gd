extends SceneTree
## AutoClicker testi. Economy gerekmez, oran ve tik sayaci disaridan enjekte edilir.
## Calistirma (proje kokunden):
##   godot --headless --path . --script res://systems/upgrades/tests/auto_clicker_test.gd
## Basarisiz test varsa cikis kodu 1 olur.

const AutoClickerScript := preload("res://systems/upgrades/auto_clicker.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_zero_rate_does_nothing()
	_test_whole_rate()
	_test_fractional_rate_accumulates()
	_test_small_ticks_accumulate()
	_test_rate_change_midway()
	_test_catchup_is_capped()
	_test_rate_drop_to_zero_clears_pending()
	_test_invalid_elapsed_ignored()
	print("AutoClicker testleri: %d kontrol, %d basarisiz" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## rate ve clicks tek elemanli dizi: lambda icinden degistirilebilsin diye.
func _make(rate: Array, clicks: Array) -> Node:
	var clicker: Node = AutoClickerScript.new()
	clicker.setup(
		func() -> float: return rate[0],
		func() -> void: clicks[0] += 1
	)
	return clicker


func _test_zero_rate_does_nothing() -> void:
	var rate := [0.0]
	var clicks := [0]
	var c := _make(rate, clicks)
	_eq(c.process_elapsed(5.0), 0, "oran 0 iken tik yok")
	_eq(clicks[0], 0, "oran 0 iken click cagrilmaz")
	c.free()


func _test_whole_rate() -> void:
	var rate := [3.0]
	var clicks := [0]
	var c := _make(rate, clicks)
	_eq(c.process_elapsed(1.0), 3, "3 tik/sn, 1 sn -> 3 tik")
	_eq(clicks[0], 3, "click aksiyonu 3 kez cagrildi")
	c.free()


func _test_fractional_rate_accumulates() -> void:
	var rate := [0.5]
	var clicks := [0]
	var c := _make(rate, clicks)
	_eq(c.process_elapsed(1.0), 0, "0.5 tik/sn, ilk saniye -> 0 tik")
	_eq(c.process_elapsed(1.0), 1, "0.5 tik/sn, ikinci saniye -> 1 tik")
	_eq(c.process_elapsed(1.0), 0, "0.5 tik/sn, ucuncu saniye -> 0 tik")
	_eq(c.process_elapsed(1.0), 1, "0.5 tik/sn, dorduncu saniye -> 1 tik")
	_eq(clicks[0], 2, "4 saniyede toplam 2 tik")
	c.free()


func _test_small_ticks_accumulate() -> void:
	# Gercek kullanim: 0.1 sn'lik tick'ler. 2.5 tik/sn -> 10 sn'de tam 25 tik.
	var rate := [2.5]
	var clicks := [0]
	var c := _make(rate, clicks)
	for _i in 100:
		c.process_elapsed(0.1)
	_eq(clicks[0], 25, "0.1 sn tick'lerle 10 sn, 2.5 tik/sn -> 25 tik")
	c.free()


func _test_rate_change_midway() -> void:
	var rate := [0.5]
	var clicks := [0]
	var c := _make(rate, clicks)
	c.process_elapsed(1.0) # birikim 0.5
	rate[0] = 2.0
	_eq(c.process_elapsed(1.0), 2, "oran artinca birikim korunur: 0.5 + 2.0 -> 2 tik")
	_eq(clicks[0], 2, "oran degisiminden sonra toplam tik")
	c.free()


func _test_catchup_is_capped() -> void:
	var rate := [10.0]
	var clicks := [0]
	var c := _make(rate, clicks)
	# 1 saat takilma: sadece MAX_CATCHUP_SECONDS (1 sn) kadar islenir.
	_eq(c.process_elapsed(3600.0), 10, "uzun takilmada tik patlamasi yok")
	c.free()


func _test_rate_drop_to_zero_clears_pending() -> void:
	var rate := [0.5]
	var clicks := [0]
	var c := _make(rate, clicks)
	c.process_elapsed(1.0) # birikim 0.5
	rate[0] = 0.0
	c.process_elapsed(1.0) # birikim sifirlanir
	rate[0] = 0.5
	_eq(c.process_elapsed(1.0), 0, "oran 0'a inince eski birikim silinir")
	c.free()


func _test_invalid_elapsed_ignored() -> void:
	var rate := [5.0]
	var clicks := [0]
	var c := _make(rate, clicks)
	_eq(c.process_elapsed(0.0), 0, "sifir sure -> tik yok")
	_eq(c.process_elapsed(-1.0), 0, "negatif sure -> tik yok")
	c.free()


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("BASARISIZ: %s (beklenen: %s, gelen: %s)" % [label, expected, actual])
