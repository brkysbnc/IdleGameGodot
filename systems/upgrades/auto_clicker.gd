extends Node
## B2 (#11). Otomatik tik: UpgradeSystem'in verdigi orana gore Economy.click() cagirir.
## Autoload DEGIL. UpgradeSystem bunu cocuk node olarak olusturur (project.godot'a dokunmaz).
## class_name KULLANMA: preload ile yuklenir, editor taramasina bagimli olmasin.
##
## Tasarim:
## - Sabit tick (0.1 sn) ile calisir, kare hizindan bagimsiz (_process yok).
## - Kesirli oranlar birikir: 0.5 tik/sn -> her 2. saniyede 1 tik.
## - Oran 0 iken Timer durur, hicbir sey calismaz.
## - Bagimliliklar Callable ile enjekte edilir (Economy'siz test edilebilir).

## Tick araligi (saniye). Economy'nin gelir tick'i ile ayni (A3).
const TICK_INTERVAL := 0.1

## Uzun takilmadan (arka plan, donma) sonra tik patlamasi olmasin diye ust sinir.
## Kapaliyken kazanc B4'un (OfflineProgress) isi, burasi degil.
const MAX_CATCHUP_SECONDS := 1.0

var _rate_source: Callable # () -> float, saniyedeki tik sayisi
var _click_action: Callable # () -> void, tek tik
var _timer: Timer
var _pending: float = 0.0 # henuz tiklanmamis kesirli tik birikimi
var _last_tick_msec: int = 0


## Bagimliliklari baglar. _ready'den once ya da sonra cagrilabilir.
func setup(rate_source: Callable, click_action: Callable) -> void:
	_rate_source = rate_source
	_click_action = click_action


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = TICK_INTERVAL
	_timer.one_shot = false
	_timer.autostart = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	refresh()


## Oran degisebilir: Timer'i gerekirse baslatir/durdurur. UpgradeSystem sinyali bunu cagirir.
func refresh() -> void:
	if _timer == null or not _rate_source.is_valid():
		return
	var rate: float = _rate_source.call()
	if rate > 0.0:
		if _timer.is_stopped():
			_last_tick_msec = Time.get_ticks_msec()
			_timer.start()
	else:
		_timer.stop()
		_pending = 0.0


## Gecen sureyi isler, yapilan tik sayisini dondurur. Test icin de acik.
func process_elapsed(elapsed: float) -> int:
	if elapsed <= 0.0 or not _rate_source.is_valid() or not _click_action.is_valid():
		return 0
	var rate: float = _rate_source.call()
	if rate <= 0.0:
		_pending = 0.0
		return 0
	_pending += rate * minf(elapsed, MAX_CATCHUP_SECONDS)
	var clicks := int(_pending)
	_pending -= clicks
	for _i in clicks:
		_click_action.call()
	return clicks


func _on_timer_timeout() -> void:
	# Timer kare basina en fazla bir kez tetiklenir, gercek gecen sureyi olcuyoruz.
	var now := Time.get_ticks_msec()
	var elapsed := (now - _last_tick_msec) / 1000.0
	_last_tick_msec = now
	process_elapsed(elapsed)
