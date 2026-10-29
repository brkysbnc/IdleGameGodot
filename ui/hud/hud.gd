class_name GameHUD
extends PanelContainer
## B8: signal-driven, coalesced updates, formatted only when the visible value changes.

const REFRESH_INTERVAL := 0.1

var currency_label: Label
var income_label: Label
var _pending_currency: BigNumber
var _pending_income: BigNumber
var _shown_currency: BigNumber
var _shown_income: BigNumber
var _timer: Timer
var refresh_count: int = 0


func _ready() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var balance := VBoxContainer.new()
	balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(balance)
	balance.add_child(GameTheme.label("YILDIZ TOZU", 28, GameTheme.MUTED))
	currency_label = GameTheme.label("0", 52, GameTheme.GOLD)
	balance.add_child(currency_label)
	var income := VBoxContainer.new()
	income.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(income)
	income.add_child(GameTheme.label("SANİYELİK GELİR", 28, GameTheme.MUTED))
	income_label = GameTheme.label("+0 / sn", 40, GameTheme.MINT)
	income.add_child(income_label)
	_timer = Timer.new()
	_timer.wait_time = REFRESH_INTERVAL
	_timer.one_shot = true
	_timer.timeout.connect(flush)
	add_child(_timer)
	_pending_currency = GameState.get_currency()
	_pending_income = Economy.get_income_per_sec()
	flush()
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.income_changed.connect(_on_income_changed)


func _on_currency_changed(value: BigNumber) -> void:
	_pending_currency = value
	_schedule()


func _on_income_changed(value: BigNumber) -> void:
	_pending_income = value
	_schedule()


func _schedule() -> void:
	if _timer.is_stopped():
		_timer.start()


func flush() -> void:
	if _pending_currency != null:
		if _shown_currency == null or not _pending_currency.equals(_shown_currency):
			var text := _pending_currency.to_string_short()
			if currency_label.text != text:
				currency_label.text = text
			_shown_currency = _pending_currency
		_pending_currency = null
	if _pending_income != null:
		if _shown_income == null or not _pending_income.equals(_shown_income):
			var text := "+%s / sn" % _pending_income.to_string_short()
			if income_label.text != text:
				income_label.text = text
			_shown_income = _pending_income
		_pending_income = null
	refresh_count += 1
