extends Node
## Oyun durumunun TEK doğruluk kaynağı (A2): para ve orbiter sayıları.
## Satın alınan upgrade'ler UpgradeSystem'de tutulur (B1), burada tekrar tutulmaz.
## Satın alma kuralları (maliyet, tık, gelir) Economy'de; burası sadece durumu değiştirir ve duyurur.
## Autoload adı: GameState (class_name KULLANMA).

const SAVE_VERSION := 1

var _currency: BigNumber = BigNumber.zero()
var _orbiter_counts: Dictionary = {} # StringName -> int


# --- Para --------------------------------------------------------------------

## Değişmez (immutable) bir BigNumber döner, paylaşılması güvenlidir.
func get_currency() -> BigNumber:
	return _currency


func add_currency(amount: BigNumber) -> void:
	if amount.is_zero():
		return
	_currency = _currency.add(amount)
	EventBus.currency_changed.emit(_currency)


## Yeterli para varsa düşer ve true döner, yoksa hiçbir şey değiştirmez.
func try_spend(cost: BigNumber) -> bool:
	if _currency.lt(cost):
		return false
	_currency = _currency.sub(cost)
	EventBus.currency_changed.emit(_currency)
	return true


# --- Orbiter sayıları --------------------------------------------------------

func get_orbiter_count(id: StringName) -> int:
	return _orbiter_counts.get(id, 0)


func add_orbiter(id: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	var count: int = get_orbiter_count(id) + amount
	_orbiter_counts[id] = count
	EventBus.orbiter_count_changed.emit(id, count)


# --- Kayıt arayüzü (SaveService kullanır) ------------------------------------

func serialize() -> Dictionary:
	var orbiters := {}
	for id: StringName in _orbiter_counts:
		orbiters[String(id)] = _orbiter_counts[id]
	return {
		"version": SAVE_VERSION,
		"currency": _currency.to_dict(),
		"orbiters": orbiters,
	}


## Eksik/bozuk veride çökmez, geçerli kısmı yükler. Sonunda UI ve orbit sistemi
## güncellensin diye durumu sinyallerle duyurur. `{}` verilirse sıfırlar.
func deserialize(data: Dictionary) -> void:
	var currency_data: Variant = data.get("currency", {})
	if currency_data is Dictionary:
		_currency = BigNumber.from_dict(currency_data)
	else:
		push_warning("GameState: kayitta 'currency' sozluk degil, sifirlandi.")
		_currency = BigNumber.zero()

	_orbiter_counts.clear()
	var saved_orbiters: Variant = data.get("orbiters", {})
	if saved_orbiters is Dictionary:
		for raw_id: Variant in saved_orbiters:
			var id := StringName(str(raw_id))
			var count := int(saved_orbiters[raw_id])
			if count <= 0:
				continue
			if GameData.get_orbiter(id) == null:
				# Icerikten kaldirilmis olabilir. Kaydi bozma, atla.
				push_warning("GameState: kayitli orbiter '%s' tanimlarda yok, atlandi." % id)
				continue
			_orbiter_counts[id] = count
	else:
		push_warning("GameState: kayitta 'orbiters' sozluk degil, yok sayildi.")

	EventBus.currency_changed.emit(_currency)
	for id: StringName in _orbiter_counts:
		EventBus.orbiter_count_changed.emit(id, _orbiter_counts[id])
