extends Node
## B1 (#10). Satin alinan upgrade'lerin carpanlarini tutar, Economy bunlari okur.
## Autoload adi: UpgradeSystem (class_name KULLANMA).
##
## Tasarim:
## - Carpanlar ONBELLEKTE. Sadece apply_upgrade / deserialize sirasinda guncellenir,
##   getter'lar sadece degisken dondurur (her cagrida hesap yok).
## - Tip ekleme = _handlers sozlugune bir satir (Open/Closed, if/else zinciri yok).
## - Upgrade verisi (UpgradeData, A4) duck-typing ile okunur: id, type,
##   target_orbiter_id, value. Boylece A4'e sert bagimlilik yok.
## - Satin alma/para kontrolu Economy'de. Burasi sadece durumu ve onbellegi tutar.
##   EventBus sinyallerini Economy atar, burasi atmaz.

## Otomatik tik orani degisti (upgrade alindi ya da kayit yuklendi).
## B'nin kendi ic sinyali, EventBus sozlesmesine dahil degil.
signal auto_click_rate_changed(rate: float)

const AutoClickerScript := preload("res://systems/upgrades/auto_clicker.gd")

## Upgrade tip anahtarlari (UpgradeData.type bu degerlerle eslesmeli).
const TYPE_AUTO_CLICK := &"auto_click"
const TYPE_PER_CLICK := &"per_click"
const TYPE_ALL_INCOME := &"all_income"
const TYPE_ALL_ORBITERS := &"all_orbiters"
const TYPE_ORBITER := &"orbiter"

## A4'te type enum (int) olarak tanimlanirsa kullanilacak sira (#6'daki liste sirasi).
const _ENUM_ORDER: Array[StringName] = [
	TYPE_AUTO_CLICK,
	TYPE_PER_CLICK,
	TYPE_ALL_INCOME,
	TYPE_ALL_ORBITERS,
	TYPE_ORBITER,
]

## Upgrade .tres dosyalarinin arandigi klasor (A4 ile ayni olmali).
const DEFINITIONS_DIR := "res://data/upgrades"

const SAVE_VERSION := 1

# --- Onbellek (sadece upgrade alininca degisir) ---
var _click_multiplier: float = 1.0
var _global_multiplier: float = 1.0
var _orbiters_multiplier: float = 1.0
var _auto_click_rate: float = 0.0
var _orbiter_multipliers: Dictionary = {} # StringName -> float

# --- Durum ---
var _purchased: Dictionary = {} # StringName -> true (hizli arama, set gibi)
var _definitions: Dictionary = {} # StringName -> UpgradeData (duck-typed)

## Tip -> o tipin onbellege nasil islendigi. Yeni tip = buraya bir satir.
var _handlers: Dictionary = {}


func _init() -> void:
	_handlers = {
		TYPE_AUTO_CLICK: _fold_auto_click,
		TYPE_PER_CLICK: _fold_per_click,
		TYPE_ALL_INCOME: _fold_all_income,
		TYPE_ALL_ORBITERS: _fold_all_orbiters,
		TYPE_ORBITER: _fold_orbiter,
	}


func _ready() -> void:
	load_definitions_from_dir(DEFINITIONS_DIR)
	_create_auto_clicker()


# ---------------------------------------------------------------- Sozlesme API

func get_click_multiplier() -> float:
	return _click_multiplier


func get_global_multiplier() -> float:
	return _global_multiplier


func get_orbiters_multiplier() -> float:
	return _orbiters_multiplier


func get_orbiter_multiplier(id: StringName) -> float:
	return _orbiter_multipliers.get(id, 1.0)


## Saniyede otomatik tik sayisi.
func get_auto_click_rate() -> float:
	return _auto_click_rate


## Economy satin almayi onaylayinca cagirir. Ayni upgrade ikinci kez uygulanmaz.
func apply_upgrade(id: StringName) -> void:
	if _purchased.has(id):
		push_warning("UpgradeSystem: '%s' zaten alinmis." % id)
		return
	var definition: Variant = _definitions.get(id)
	if definition == null:
		push_warning("UpgradeSystem: bilinmeyen upgrade '%s'." % id)
		return
	var rate_before := _auto_click_rate
	if not _fold(definition):
		return
	_purchased[id] = true
	_emit_if_auto_click_rate_changed(rate_before)


func is_purchased(id: StringName) -> bool:
	return _purchased.has(id)


## Kayit arayuzu (SaveService kullanir).
func serialize() -> Dictionary:
	var ids: Array[String] = []
	for id: StringName in _purchased:
		ids.append(String(id))
	ids.sort() # kararli cikti, diff'te gurultu yok
	return {"version": SAVE_VERSION, "purchased": ids}


func deserialize(data: Dictionary) -> void:
	var rate_before := _auto_click_rate
	_reset()
	_apply_saved_ids(data.get("purchased", []))
	_emit_if_auto_click_rate_changed(rate_before)


func _apply_saved_ids(ids: Variant) -> void:
	if not ids is Array:
		push_warning("UpgradeSystem: kayitta 'purchased' dizi degil, yok sayildi.")
		return
	for raw_id: Variant in ids:
		var id := StringName(str(raw_id))
		var definition: Variant = _definitions.get(id)
		if definition == null:
			# Icerikten kaldirilmis olabilir. Kaydi bozma, atla.
			push_warning("UpgradeSystem: kayitli upgrade '%s' tanimlarda yok, atlandi." % id)
			continue
		if _fold(definition):
			_purchased[id] = true


# ------------------------------------------------------------- Veri yukleme

## Upgrade tanimlarini yukler. Test ve ozel yukleme icin dis API.
## Ayni id tekrar gelirse son gelen gecerli olur (uyari ile).
func register_definitions(definitions: Array) -> void:
	for definition: Variant in definitions:
		var id := _read_id(definition)
		if id == &"":
			push_warning("UpgradeSystem: id'si bos bir tanim atlandi.")
			continue
		if _definitions.has(id):
			push_warning("UpgradeSystem: '%s' birden fazla tanimlanmis, sonuncusu kullanildi." % id)
		_definitions[id] = definition


## Klasordeki tum .tres dosyalarini tanim olarak yukler (export'ta .remap'li de calisir).
func load_definitions_from_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# A4 henuz klasoru eklemedi olabilir, hata degil.
		return
	var loaded: Array = []
	for file_name in dir.get_files():
		var clean_name := file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var resource := load(dir_path.path_join(clean_name))
		if resource == null:
			push_warning("UpgradeSystem: '%s' yuklenemedi." % clean_name)
			continue
		loaded.append(resource)
	register_definitions(loaded)


# ----------------------------------------------------------- Onbellek islemleri

func _reset() -> void:
	_click_multiplier = 1.0
	_global_multiplier = 1.0
	_orbiters_multiplier = 1.0
	_auto_click_rate = 0.0
	_orbiter_multipliers.clear()
	_purchased.clear()


func _emit_if_auto_click_rate_changed(rate_before: float) -> void:
	if not is_equal_approx(rate_before, _auto_click_rate):
		auto_click_rate_changed.emit(_auto_click_rate)


## AutoClicker'i cocuk node olarak kurar. Economy'ye bagimlilik sadece burada.
func _create_auto_clicker() -> void:
	var economy := get_node_or_null("/root/Economy")
	if economy == null:
		push_warning("UpgradeSystem: Economy autoload'u bulunamadi, otomatik tik kapali.")
		return
	var clicker: Node = AutoClickerScript.new()
	clicker.setup(get_auto_click_rate, economy.click)
	add_child(clicker)
	auto_click_rate_changed.connect(func(_rate: float) -> void: clicker.refresh())


## Tek bir upgrade'i onbellege isler. Basariliysa true.
func _fold(definition: Variant) -> bool:
	var type_key := _read_type(definition)
	var handler: Callable = _handlers.get(type_key, Callable())
	if handler.is_null():
		push_warning("UpgradeSystem: bilinmeyen upgrade tipi '%s' (id: '%s')." % [type_key, _read_id(definition)])
		return false
	var value := float(definition.get("value"))
	handler.call(definition, value)
	return true


func _fold_auto_click(_definition: Variant, value: float) -> void:
	_auto_click_rate += value # saniyedeki tik sayisi toplanir


func _fold_per_click(_definition: Variant, value: float) -> void:
	_click_multiplier *= value


func _fold_all_income(_definition: Variant, value: float) -> void:
	_global_multiplier *= value


func _fold_all_orbiters(_definition: Variant, value: float) -> void:
	_orbiters_multiplier *= value


func _fold_orbiter(definition: Variant, value: float) -> void:
	var target := StringName(str(definition.get("target_orbiter_id")))
	_orbiter_multipliers[target] = float(_orbiter_multipliers.get(target, 1.0)) * value


# ---------------------------------------------------------------- Okuma yardimcilari

func _read_id(definition: Variant) -> StringName:
	return StringName(str(definition.get("id")))


## type alani StringName/String ya da enum (int) olabilir, ikisi de desteklenir.
func _read_type(definition: Variant) -> StringName:
	var raw: Variant = definition.get("type")
	if raw is int:
		var index := raw as int
		if index >= 0 and index < _ENUM_ORDER.size():
			return _ENUM_ORDER[index]
		return &""
	return StringName(str(raw))
