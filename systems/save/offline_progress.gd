extends Node
## B4 (#13). Oyun kapaliyken/arka plandayken gecen sure icin kazanc verir.
## Autoload DEGIL: SaveService bunu cocuk node olarak kurar ve kayit parcasi olarak kaydeder.
## class_name KULLANMA: preload ile yuklenir.
##
## Nasil calisir:
## - serialize() her kayitta {"saved_at": simdi} yazar (son kaydetme zamani).
## - deserialize() sadece saved_at'i okur. Kazanc post_load()'da verilir: SaveService bunu TUM parcalar
##   geri yuklendikten ve Economy.refresh() cagrildiktan sonra calistirir, boylece gelir guncel carpanlarla hesaplanir.
## - Kazanc verilince offline_earnings_granted atilir, SaveService hemen kaydeder. Aksi halde saved_at
##   eski kalir ve uygulama 30 sn icinde olurse ayni sure ikinci kez odenirdi.
## - Mobilde arka plana gidince (APPLICATION_PAUSED) saat tutulur, donunce (APPLICATION_RESUMED) kazanc verilir.
##   Arka planda gecen sure sadece burada hesaplanir.
##
## Neden FOCUS_IN/OUT dinlenmiyor: PC'de pencere odagi kaybedince oyun calismaya devam eder,
## gelir zaten islemistir. Odak olayinda ayrica kazanc vermek ayni sureyi iki kez odemek olurdu.
## PAUSED/RESUMED sadece uygulama gercekten askiya alininca gelir (Android/iOS).
##
## Para ekleme: GameState.add_currency(amount: BigNumber) (A2). Bulunamazsa kazanc VERILMEZ ve ozet de GOSTERILMEZ.

## Bir kazanc verildi (ozet gosterimi icin).
signal offline_earnings_granted(earned: Variant, away_seconds: float)

const PopupScript := preload("res://systems/save/offline_summary_popup.gd")

## Kazanc icin sayilan en fazla sure (8 saat).
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0

## Bundan kisa ayrilmalar yok sayilir (hizli yeniden acilis/kisa arka plan icin popup spam'i olmasin).
const MIN_AWAY_SECONDS := 60.0

var _now_source: Callable # () -> float, unix saniye
var _income_source: Callable # () -> BigNumber, saniyelik gelir
var _credit_action: Callable # (earned: BigNumber) -> void
var _left_at: float = -1.0 # arka plana gidilen an, -1 = uygulama on planda
var _pending_away_seconds: float = 0.0 # acilista kayittan hesaplanan, post_load'da odenecek sure


## Bagimliliklari baglar (test icin enjekte edilebilir).
func setup(now_source: Callable, income_source: Callable, credit_action: Callable) -> void:
	_now_source = now_source
	_income_source = income_source
	_credit_action = credit_action


func _ready() -> void:
	if not _now_source.is_valid():
		_wire_defaults()
	offline_earnings_granted.connect(_show_summary)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# Ilk ayrilma sayilir, art arda gelen ikinci olay saati ileri almaz.
			if _left_at < 0.0:
				_left_at = _now()
		NOTIFICATION_APPLICATION_RESUMED:
			if _left_at >= 0.0:
				var away := _now() - _left_at
				_left_at = -1.0
				grant(away)


# ----------------------------------------------------------- Kayit parcasi

func serialize() -> Dictionary:
	return {"saved_at": _now()}


func deserialize(data: Dictionary) -> void:
	var saved_at := float(data.get("saved_at", 0.0))
	_pending_away_seconds = _now() - saved_at if saved_at > 0.0 else 0.0


## SaveService, tum parcalar geri yuklendikten sonra cagirir.
func post_load() -> void:
	var away := _pending_away_seconds
	_pending_away_seconds = 0.0
	if away > 0.0:
		grant(away)


# ----------------------------------------------------------------- Kazanc

## Ayrilik suresi icin kazanci verir. Verildiyse true.
## Negatif sure (sistem saati geri alindi) ve cok kisa sureler kazanc vermez, uzun sure 8 saatle sinirlanir.
func grant(away_seconds: float) -> bool:
	if not _income_source.is_valid() or not _credit_action.is_valid():
		return false
	var seconds := minf(away_seconds, MAX_OFFLINE_SECONDS)
	if seconds < MIN_AWAY_SECONDS:
		return false
	var income: Variant = _income_source.call()
	if income == null:
		return false
	var earned: Variant = income.mul_float(seconds)
	if earned == null or earned.mantissa <= 0.0:
		return false
	_credit_action.call(earned)
	offline_earnings_granted.emit(earned, seconds)
	return true


# --------------------------------------------------------------- Yardimcilar

func _now() -> float:
	if _now_source.is_valid():
		return _now_source.call()
	return Time.get_unix_time_from_system()


func _wire_defaults() -> void:
	_now_source = func() -> float: return Time.get_unix_time_from_system()
	var economy := get_node_or_null("/root/Economy")
	if economy == null:
		push_warning("OfflineProgress: Economy autoload'u bulunamadi, offline kazanc kapali.")
		return
	_income_source = economy.get_income_per_sec
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("add_currency"):
		_credit_action = game_state.add_currency
	else:
		push_warning("OfflineProgress: GameState.add_currency(amount) bulunamadi, offline kazanc kapali.")


func _show_summary(earned: Variant, away_seconds: float) -> void:
	var popup := PopupScript.new()
	popup.message = "Yokken %s kazandın!\n(%s)" % [earned.to_string_short(), PopupScript.format_duration(away_seconds)]
	# Autoload acilisinda root hala meşgul olabilir, bu yuzden ertelenir.
	get_tree().root.add_child.call_deferred(popup)
