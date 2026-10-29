extends Node
## Ekonomi kuralları (A3): tık geliri, saniyelik gelir, maliyet eğrisi, satın alma.
## Durumu GameState tutar, çarpanları UpgradeSystem verir (B1), içerik GameData'dan gelir.
## Autoload adı: Economy (class_name KULLANMA).
##
## Autoload sırası önemli: Economy, UpgradeSystem'den ÖNCE yüklenir. UpgradeSystem._ready
## Economy'yi bulur (otomatik tıklayıcıyı bağlamak için). Bu yüzden burada _ready içinde
## UpgradeSystem'e dokunulmaz, çarpanlar ilk ihtiyaçta (tembel) okunur.
##
## Gelir TEK sabit tick'te (0.1 sn) eklenir, kare hızından bağımsız. Saniyelik gelir önbellekte,
## sadece orbiter sayısı ya da upgrade değişince yeniden hesaplanır.

## Gelir tick aralığı (saniye).
const TICK_INTERVAL := 0.1
## Uzun takılma ya da arka plan sonrası tek tick'te en fazla bu kadar saniyelik gelir eklenir.
## Kapalıyken kazanç OfflineProgress'in (B4) işidir, çift sayım olmasın.
const MAX_CATCHUP_SECONDS := 1.0
## Hiç upgrade yokken tek tıklamanın değeri.
const BASE_CLICK_VALUE := 1.0

var _income_per_sec: BigNumber = BigNumber.zero()
var _income_dirty: bool = true
var _timer: Timer
var _last_tick_msec: int = 0


func _ready() -> void:
	EventBus.orbiter_count_changed.connect(_on_orbiter_count_changed)
	_timer = Timer.new()
	_timer.wait_time = TICK_INTERVAL
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_last_tick_msec = Time.get_ticks_msec()
	_timer.start()


# --- Tık ---------------------------------------------------------------------

## Yıldıza tıklama. Kazanılan miktarı döner (floating text için).
## Tık değeri = temel değer x tık çarpanı x genel gelir çarpanı.
func click() -> BigNumber:
	var value := get_click_value()
	GameState.add_currency(value)
	return value


func get_click_value() -> BigNumber:
	return BigNumber.from_float(
		BASE_CLICK_VALUE * UpgradeSystem.get_click_multiplier() * UpgradeSystem.get_global_multiplier()
	)


# --- Gelir -------------------------------------------------------------------

## Önbellekten döner, sadece değişiklik sonrası yeniden hesaplanır.
func get_income_per_sec() -> BigNumber:
	if _income_dirty:
		_income_per_sec = _compute_income()
		_income_dirty = false
	return _income_per_sec


## Tek bir orbiter adedinin saniyelik geliri (tüm çarpanlar dahil). Hem toplam gelir hem
## mağaza paneli bunu kullanır (DRY).
func get_orbiter_unit_income(id: StringName) -> BigNumber:
	var data := GameData.get_orbiter(id)
	if data == null:
		return BigNumber.zero()
	return BigNumber.from_float(
		data.base_income
		* UpgradeSystem.get_orbiter_multiplier(id)
		* UpgradeSystem.get_orbiters_multiplier()
		* UpgradeSystem.get_global_multiplier()
	)


## Dış durum (kayıt yükleme) Economy'nin haberi olmadan değiştiyse çağrılır:
## önbelleği düşürür ve income_changed sinyali atar. SaveService yüklemeden sonra çağırmalı.
func refresh() -> void:
	_income_dirty = true
	EventBus.income_changed.emit(get_income_per_sec())


## Geçen süreyi gelire çevirir. Tick'ten çağrılır, testte doğrudan çağrılabilir.
func process_elapsed(elapsed: float) -> void:
	if elapsed <= 0.0:
		return
	var income := get_income_per_sec()
	if income.is_zero():
		return
	GameState.add_currency(income.mul_float(minf(elapsed, MAX_CATCHUP_SECONDS)))


# --- Satın alma --------------------------------------------------------------

func get_orbiter_count(id: StringName) -> int:
	return GameState.get_orbiter_count(id)


## Sıradaki adedin maliyeti: base_cost * cost_growth^(sahip olunan adet).
func get_orbiter_cost(id: StringName) -> BigNumber:
	var data := GameData.get_orbiter(id)
	if data == null:
		push_error("Economy: bilinmeyen orbiter '%s'" % id)
		return BigNumber.zero()
	return BigNumber.from_float(data.base_cost).mul_pow(data.cost_growth, GameState.get_orbiter_count(id))


func try_buy_orbiter(id: StringName) -> bool:
	if GameData.get_orbiter(id) == null:
		return false
	if not GameState.try_spend(get_orbiter_cost(id)):
		return false
	GameState.add_orbiter(id) # orbiter_count_changed -> gelir yeniden hesaplanır
	return true


func try_buy_upgrade(id: StringName) -> bool:
	var data := GameData.get_upgrade(id)
	if data == null or UpgradeSystem.is_purchased(id):
		return false
	var cost := BigNumber.from_float(data.cost)
	if not GameState.try_spend(cost):
		return false
	UpgradeSystem.apply_upgrade(id)
	if not UpgradeSystem.is_purchased(id):
		# UpgradeSystem uygulayamadı (bilinmeyen tip vb.): parayı iade et.
		GameState.add_currency(cost)
		return false
	refresh()
	EventBus.upgrade_purchased.emit(id)
	return true


# --- İç ----------------------------------------------------------------------

func _compute_income() -> BigNumber:
	var total := BigNumber.zero()
	for orbiter in GameData.orbiters():
		var count := GameState.get_orbiter_count(orbiter.id)
		if count == 0:
			continue
		total = total.add(get_orbiter_unit_income(orbiter.id).mul_float(count))
	return total


func _on_orbiter_count_changed(_id: StringName, _count: int) -> void:
	refresh()


func _on_timer_timeout() -> void:
	# Timer kare başına en fazla bir kez tetiklenir, bu yüzden gerçek geçen süreyi ölçüyoruz.
	var now := Time.get_ticks_msec()
	var elapsed := (now - _last_tick_msec) / 1000.0
	_last_tick_msec = now
	process_elapsed(elapsed)
