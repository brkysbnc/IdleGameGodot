class_name OrbiterRow
extends PanelContainer
## Orbiters listesinde bir satır (A5): ad, adet, tek adet geliri ve satın al butonu.
## `data/orbiters/` içindeki OrbiterData'dan otomatik oluşturulur.

var _data: OrbiterData
var _name_label: Label
var _info_label: Label
var _buy_button: Button
var _cost: BigNumber = BigNumber.zero()


## add_child'dan ÖNCE çağır.
func setup(data: OrbiterData) -> OrbiterRow:
	_data = data
	return self


func _ready() -> void:
	custom_minimum_size.y = ShopStyle.MIN_TOUCH_SIZE
	var row := HBoxContainer.new()
	add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	_name_label = ShopStyle.make_label()
	_info_label = ShopStyle.make_label(ShopStyle.FONT_SIZE_SMALL)
	texts.add_child(_name_label)
	texts.add_child(_info_label)
	_buy_button = ShopStyle.make_buy_button()
	_buy_button.pressed.connect(_on_buy_pressed)
	row.add_child(_buy_button)
	refresh_full()


## Adet, gelir ve maliyet metinlerini yeniler. Sadece sayı/upgrade değişince çağrılır.
func refresh_full() -> void:
	var id := _data.id
	_name_label.text = "%s  x%d" % [_data.display_name, Economy.get_orbiter_count(id)]
	_info_label.text = "Her biri +%s/sn" % Economy.get_orbiter_unit_income(id).to_string_short()
	_cost = Economy.get_orbiter_cost(id)
	_buy_button.text = ShopStyle.buy_text(_cost)
	refresh_affordability()


## Sadece buton aktifliği (para değişince, ~10 Hz'e kadar çağrılır). Metin üretmez.
func refresh_affordability() -> void:
	_buy_button.disabled = not GameState.get_currency().gte(_cost)


func _on_buy_pressed() -> void:
	Economy.try_buy_orbiter(_data.id)
