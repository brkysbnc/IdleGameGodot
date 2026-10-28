class_name ShopStyle
extends RefCounted
## Mağaza arayüzünün ortak sabitleri ve küçük yardımcıları (A5/A6, DRY).
## Ölçüler 1920x1080 tasarım çözünürlüğüne göre. Dokunmatik hedef en az 96 px.

const MIN_TOUCH_SIZE := 96
const FONT_SIZE := 30
const FONT_SIZE_SMALL := 24
const BUY_BUTTON_WIDTH := 240
const ROW_SPACING := 8
## Kaydırırken yanlışlıkla basma olmasın: bu kadar piksel sürüklenince kaydırma başlar.
const SCROLL_DEADZONE := 16
## Para değişimine bağlı yenilemeler en fazla bu aralıkla yapılır (~10 Hz).
const REFRESH_INTERVAL := 0.1


static func make_label(font_size: int = FONT_SIZE) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func make_buy_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(BUY_BUTTON_WIDTH, MIN_TOUCH_SIZE)
	button.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	return button


static func buy_text(cost: BigNumber) -> String:
	return "Satın Al\n%s" % cost.to_string_short()
