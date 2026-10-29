class_name UpgradeRow
extends PanelContainer
## Upgrade satırı (A5/A6): ad, açıklama, satın al butonu. Hem mağaza paneli hem
## Orbiter Upgrade menüsü kullanır. Satın alınınca satır kendini gizler.

var _data: UpgradeData
var _cost: BigNumber = BigNumber.zero()
var _buy_button: Button


## add_child'dan ÖNCE çağır.
func setup(data: UpgradeData) -> UpgradeRow:
	_data = data
	_cost = BigNumber.from_float(data.cost)
	return self


func _ready() -> void:
	custom_minimum_size.y = ShopStyle.MIN_TOUCH_SIZE
	var row := HBoxContainer.new()
	add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var name_label := ShopStyle.make_label()
	name_label.text = _data.display_name
	var description_label := ShopStyle.make_label(ShopStyle.FONT_SIZE_SMALL)
	description_label.text = _data.description
	texts.add_child(name_label)
	texts.add_child(description_label)
	_buy_button = ShopStyle.make_buy_button()
	_buy_button.text = ShopStyle.buy_text(_cost)
	_buy_button.pressed.connect(_on_buy_pressed)
	row.add_child(_buy_button)
	refresh_state()


## Satın alındıysa gizler, değilse buton aktifliğini yeniler. Metin üretmez.
func refresh_state() -> void:
	var owned := UpgradeSystem.is_purchased(_data.id)
	visible = not owned
	if not owned:
		_buy_button.disabled = not GameState.get_currency().gte(_cost)


func _on_buy_pressed() -> void:
	Economy.try_buy_upgrade(_data.id)
