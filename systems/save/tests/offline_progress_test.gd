extends SceneTree
## OfflineProgress testi. Economy/BigNumber gerekmez, saat, gelir ve kredi enjekte edilir.
## Calistirma (proje kokunden):
##   godot --headless --path . --script res://systems/save/tests/offline_progress_test.gd
## Basarisiz test varsa cikis kodu 1 olur.

const OfflineProgressScript := preload("res://systems/save/offline_progress.gd")
const PopupScript := preload("res://systems/save/offline_summary_popup.gd")

var _failures := 0
var _checks := 0


## BigNumber yerine gecen sahte sayi (mantissa + mul_float).
class FakeNumber extends RefCounted:
	var mantissa: float = 0.0

	func _init(p_value: float = 0.0) -> void:
		mantissa = p_value

	func mul_float(factor: float) -> FakeNumber:
		return FakeNumber.new(mantissa * factor)


func _init() -> void:
	_test_normal_grant()
	_test_cap_at_eight_hours()
	_test_clock_rollback_gives_nothing()
	_test_too_short_gives_nothing()
	_test_zero_income_gives_nothing()
	_test_missing_credit_gives_nothing()
	_test_serialize_writes_now()
	_test_deserialize_grants_since_saved_at()
	_test_deserialize_without_saved_at()
	_test_pause_resume_grants()
	_test_double_pause_keeps_first_time()
	_test_resume_without_pause_gives_nothing()
	_test_format_duration()
	print("OfflineProgress testleri: %d kontrol, %d basarisiz" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## clock: [simdi], earned: kredi edilen sayilar, events: sinyal sayisi/saniyeleri.
func _make(clock: Array, income: float, earned: Array, events: Array, with_credit := true) -> Node:
	var node: Node = OfflineProgressScript.new()
	var credit := Callable()
	if with_credit:
		credit = func(amount: FakeNumber) -> void: earned.append(amount.mantissa)
	node.setup(
		func() -> float: return clock[0],
		func() -> FakeNumber: return FakeNumber.new(income),
		credit
	)
	node.offline_earnings_granted.connect(func(_e: Variant, seconds: float) -> void: events.append(seconds))
	return node


func _test_normal_grant() -> void:
	var earned := []
	var events := []
	var n := _make([0.0], 10.0, earned, events)
	_eq(n.grant(100.0), true, "normal ayrilik kazanc verir")
	_eq(earned, [1000.0], "kazanc = sure x gelir")
	_eq(events, [100.0], "sinyal ayrilik suresiyle atildi")
	n.free()


func _test_cap_at_eight_hours() -> void:
	var earned := []
	var events := []
	var n := _make([0.0], 1.0, earned, events)
	n.grant(100.0 * 3600.0)
	_eq(events, [8.0 * 3600.0], "100 saat 8 saate sinirlandi")
	_eq(earned, [8.0 * 3600.0], "kazanc 8 saatlik")
	n.free()


func _test_clock_rollback_gives_nothing() -> void:
	var earned := []
	var events := []
	var n := _make([0.0], 10.0, earned, events)
	_eq(n.grant(-5000.0), false, "saat geri alinirsa kazanc yok")
	_eq(earned.size(), 0, "negatif sure kredi etmez")
	n.free()


func _test_too_short_gives_nothing() -> void:
	var earned := []
	var events := []
	var n := _make([0.0], 10.0, earned, events)
	_eq(n.grant(10.0), false, "cok kisa ayrilik kazanc vermez")
	_eq(events.size(), 0, "cok kisa ayrilikta sinyal yok")
	n.free()


func _test_zero_income_gives_nothing() -> void:
	var earned := []
	var events := []
	var n := _make([0.0], 0.0, earned, events)
	_eq(n.grant(3600.0), false, "gelir 0 iken kazanc yok")
	_eq(events.size(), 0, "gelir 0 iken ozet gosterilmez")
	n.free()


func _test_missing_credit_gives_nothing() -> void:
	var earned := []
	var events := []
	var n := _make([0.0], 10.0, earned, events, false)
	_eq(n.grant(3600.0), false, "credit yoksa kazanc verilmez")
	_eq(events.size(), 0, "credit yoksa ozet gosterilmez (yalan soylemez)")
	n.free()


func _test_serialize_writes_now() -> void:
	var n := _make([1234567.0], 1.0, [], [])
	_eq(n.serialize(), {"saved_at": 1234567.0}, "serialize son kaydetme zamanini yazar")
	n.free()


func _test_deserialize_grants_since_saved_at() -> void:
	var earned := []
	var events := []
	var clock := [10000.0]
	var n := _make(clock, 2.0, earned, events)
	n.deserialize({"saved_at": 9000.0}) # 1000 sn once
	_eq(earned.size(), 0, "deserialize tek basina odeme yapmaz")
	n.post_load()
	_eq(earned, [2000.0], "post_load saved_at'ten beri gecen sureyi oder")
	n.post_load()
	_eq(earned.size(), 1, "post_load ikinci kez odeme yapmaz")
	n.free()


func _test_deserialize_without_saved_at() -> void:
	var earned := []
	var n := _make([10000.0], 2.0, earned, [])
	n.deserialize({})
	n.post_load()
	n.deserialize({"saved_at": 0.0})
	n.post_load()
	_eq(earned.size(), 0, "saved_at yoksa/0 ise kazanc yok")
	n.free()


func _test_pause_resume_grants() -> void:
	var earned := []
	var clock := [1000.0]
	var n := _make(clock, 1.0, earned, [])
	n._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	clock[0] = 1600.0
	n._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_eq(earned, [600.0], "arka plandan donunce gecen sure odenir")
	n.free()


func _test_double_pause_keeps_first_time() -> void:
	var earned := []
	var clock := [1000.0]
	var n := _make(clock, 1.0, earned, [])
	n._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	clock[0] = 1300.0
	n._notification(Node.NOTIFICATION_APPLICATION_PAUSED) # art arda gelen ikinci olay
	clock[0] = 1600.0
	n._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_eq(earned, [600.0], "ilk ayrilma zamani korunur")
	clock[0] = 2600.0
	n._notification(Node.NOTIFICATION_APPLICATION_RESUMED) # ikinci resume
	_eq(earned.size(), 1, "ayni ayrilik iki kez odenmez")
	n.free()


func _test_resume_without_pause_gives_nothing() -> void:
	var earned := []
	var n := _make([5000.0], 1.0, earned, [])
	n._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_eq(earned.size(), 0, "pause olmadan resume kazanc vermez")
	n.free()


func _test_format_duration() -> void:
	_eq(PopupScript.format_duration(30.0), "0 dk", "30 sn")
	_eq(PopupScript.format_duration(45.0 * 60.0), "45 dk", "45 dk")
	_eq(PopupScript.format_duration(2.0 * 3600.0 + 15.0 * 60.0), "2 sa 15 dk", "2 sa 15 dk")
	_eq(PopupScript.format_duration(8.0 * 3600.0), "8 sa 0 dk", "8 sa")
	_eq(PopupScript.format_duration(-5.0), "0 dk", "negatif sure 0 dk")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("BASARISIZ: %s (beklenen: %s, gelen: %s)" % [label, expected, actual])
