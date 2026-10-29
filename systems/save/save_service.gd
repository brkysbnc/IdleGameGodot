extends Node
## B3 (#12). GameState ve UpgradeSystem serialize() sonuclarini toplayip user://save.json'a yazar,
## acilista deserialize() ile geri dagitir.
## Autoload adi: SaveService (class_name KULLANMA).
##
## Dosya bicimi:
##   {"version": 1, "sections": {"game_state": {...}, "upgrades": {...}}}
## - Yeni kayit parcasi = register_section() ile bir satir (Open/Closed).
## - Ust duzey alanlar (ornegin B4'un "saved_at"i) "version" ile "sections" yaninda durabilir.
## - Surum degisirse _migrations sozlugune (eski surum -> Callable) adim eklenir.
## - Parcanin post_load() metodu varsa, TUM parcalar geri yuklendikten ve Economy.refresh() cagrildiktan sonra calisir.
##
## Guvenlik:
## - Atomik yazma: once .tmp'ye yazilir, sonra adlandirilir. Kayit sirasinda surec olurse eski kayit bozulmaz.
## - Her kayitta bir oncekinin yedegi (.bak) tutulur.
## - Bozuk/okunamayan kayit oyunu cokertmez: .corrupt.json olarak saklanir, yedek denenir, o da yoksa temiz baslanir.
##
## JSON notu: sayilar JSON'dan float geri gelir (3 -> 3.0). Okuyan taraf (GameState vb.) int()'e cevirmelidir.
## BigNumber nesneleri kayit sirasinda to_dict() ile yazilir, okurken BigNumber.from_dict() ile geri kurulur.

const OfflineProgressScript := preload("res://systems/save/offline_progress.gd")

const SAVE_PATH := "user://save.json"
const ECONOMY_PATH := "/root/Economy"
const FORMAT_VERSION := 1
const AUTOSAVE_INTERVAL := 30.0

## Mobilde PAUSED ve FOCUS_OUT art arda gelir, ayni anda iki kez yazmayalim.
const LIFECYCLE_SAVE_MIN_GAP_MSEC := 1000

## Varsayilan kayit parcalari: anahtar -> autoload yolu.
const DEFAULT_SECTIONS := {
	&"game_state": "/root/GameState",
	&"upgrades": "/root/UpgradeSystem",
}

## Testler icin degistirilebilir. Yedek/tmp/bozuk dosya yollari buradan turetilir.
var save_path: String = SAVE_PATH

var _sections: Dictionary = {} # StringName -> Object (serialize/deserialize'i olan)
var _migrations: Dictionary = {} # eski surum (int) -> Callable(data: Dictionary) -> Dictionary
var _autosave_timer: Timer
var _last_save_msec: int = -LIFECYCLE_SAVE_MIN_GAP_MSEC


func _ready() -> void:
	_register_default_sections()
	_register_offline_progress()
	load_game()
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.one_shot = false
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)
	_autosave_timer.start()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			# PC: pencere kapaniyor, her zaman kaydet.
			save_game()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Mobil: surec haber verilmeden oldurulebilir, arka plana giderken kaydet.
			_save_throttled()


# ---------------------------------------------------------------- Genel API

## Kayit parcasi ekler. provider'in serialize() ve deserialize(data) metodlari olmali.
func register_section(key: StringName, provider: Object) -> void:
	if provider == null or not provider.has_method("serialize") or not provider.has_method("deserialize"):
		push_error("SaveService: '%s' icin gecersiz provider (serialize/deserialize yok)." % key)
		return
	_sections[key] = provider


## Tum parcalari toplayip diske yazar. Basariliysa true.
func save_game() -> bool:
	var sections := {}
	for key: StringName in _sections:
		sections[String(key)] = _to_json_safe((_sections[key] as Object).call("serialize"))
	var envelope := {"version": FORMAT_VERSION, "sections": sections}
	# full_precision: mantissa gibi float'lar kayipsiz yazilir.
	var text := JSON.stringify(envelope, "\t", true, true)
	return _write_atomic(text)


## Kaydi okuyup parcalara dagitir. Okunduysa true, temiz baslangicsa false.
## Once ana dosya, o bozuksa yedek denenir. Hicbiri yoksa/gecerliyse oyun varsayilanlarla baslar.
func load_game() -> bool:
	for path: String in [save_path, _backup_path()]:
		if not FileAccess.file_exists(path):
			continue
		var envelope := _read_envelope(path)
		if envelope.is_empty():
			push_warning("SaveService: '%s' okunamadi." % path)
			if path == save_path:
				_quarantine_corrupt()
			continue
		_distribute(envelope)
		_after_load()
		return true
	return false


# ------------------------------------------------------------------- Yazma

func _write_atomic(text: String) -> bool:
	var tmp_path := _tmp_path()
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: '%s' acilamadi (%s)." % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("SaveService: yazma hatasi (%s)." % error_string(write_error))
		DirAccess.remove_absolute(tmp_path)
		return false
	# Eski kayit gecerli oldugu icin yedege alinir (en iyi caba, basarisizsa devam).
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, _backup_path())
	var rename_error := DirAccess.rename_absolute(tmp_path, save_path)
	if rename_error != OK:
		push_error("SaveService: '%s' yerine konamadi (%s)." % [save_path, error_string(rename_error)])
		return false
	_last_save_msec = Time.get_ticks_msec()
	return true


## JSON'a yazilamayan degerleri guvenli hale getirir:
## BigNumber (to_dict'i olan nesne) -> sozluk, StringName -> String, NaN/INF -> 0.0.
func _to_json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out_dict := {}
			for key: Variant in value:
				out_dict[str(key)] = _to_json_safe(value[key])
			return out_dict
		TYPE_ARRAY:
			var out_array := []
			for item: Variant in value:
				out_array.append(_to_json_safe(item))
			return out_array
		TYPE_OBJECT:
			if value != null and (value as Object).has_method("to_dict"):
				return _to_json_safe((value as Object).call("to_dict"))
			push_error("SaveService: kayda yazilamayan nesne, null yazildi.")
			return null
		TYPE_STRING_NAME:
			return String(value)
		TYPE_FLOAT:
			if not is_finite(value):
				push_error("SaveService: sonlu olmayan sayi (NaN/INF), 0 yazildi.")
				return 0.0
			return value
	return value


func _save_throttled() -> void:
	if Time.get_ticks_msec() - _last_save_msec < LIFECYCLE_SAVE_MIN_GAP_MSEC:
		return
	save_game()


func _on_autosave_timeout() -> void:
	save_game()


# ------------------------------------------------------------------- Okuma

## Dosyayi okuyup dogrular. Gecersizse bos sozluk doner.
func _read_envelope(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if not json.data is Dictionary:
		return {}
	var envelope: Dictionary = json.data
	var raw_version: Variant = envelope.get("version")
	if not (raw_version is float or raw_version is int):
		return {}
	var version := int(raw_version)
	# Oyundan yeni surumle yazilmis kaydi anlayamayiz, eskiyse migrasyon dener.
	if version < 1 or version > FORMAT_VERSION:
		return {}
	envelope = _migrate(envelope, version)
	if not envelope.get("sections") is Dictionary:
		return {}
	return envelope


## Eski surum kaydini adim adim guncel surume tasir. Adim yoksa kayit okunamaz sayilir.
func _migrate(envelope: Dictionary, from_version: int) -> Dictionary:
	var version := from_version
	while version < FORMAT_VERSION:
		var step: Callable = _migrations.get(version, Callable())
		if step.is_null():
			push_error("SaveService: surum %d icin migrasyon yok." % version)
			return {}
		envelope = step.call(envelope)
		version += 1
	return envelope


## Kayit parcalarini sahiplerine verir. Eksik ya da sozluk olmayan parca atlanir (varsayilan kalir).
func _distribute(envelope: Dictionary) -> void:
	var sections: Dictionary = envelope["sections"]
	for key: StringName in _sections:
		var payload: Variant = sections.get(String(key))
		if payload is Dictionary:
			(_sections[key] as Object).call("deserialize", payload)


## Tum parcalar geri yuklendikten SONRA calisir:
## 1) Economy gelir onbellegini dusurur (A3: "SaveService yuklemeden sonra refresh() cagirmali").
##    UpgradeSystem.deserialize carpanlari sinyalsiz degistirdigi icin bu sart.
## 2) post_load() metodu olan parcalar cagrilir (ornegin offline kazanc, guncel gelirle hesaplanmali).
func _after_load() -> void:
	if is_inside_tree():
		var economy := get_node_or_null(ECONOMY_PATH)
		if economy != null and economy.has_method("refresh"):
			economy.call("refresh")
	for key: StringName in _sections:
		var provider := _sections[key] as Object
		if provider.has_method("post_load"):
			provider.call("post_load")


## Bozuk ana kaydi silmeden kenara alir, sonraki otomatik kayit onu ezmesin.
func _quarantine_corrupt() -> void:
	var corrupt_path := _corrupt_path()
	if FileAccess.file_exists(corrupt_path):
		DirAccess.remove_absolute(corrupt_path)
	var error := DirAccess.rename_absolute(save_path, corrupt_path)
	if error != OK:
		push_warning("SaveService: bozuk kayit kenara alinamadi (%s)." % error_string(error))


# --------------------------------------------------------------- Yardimcilar

func _register_default_sections() -> void:
	for key: StringName in DEFAULT_SECTIONS:
		var provider := get_node_or_null(DEFAULT_SECTIONS[key] as String)
		if provider == null:
			push_warning("SaveService: '%s' autoload'u bulunamadi, kayda dahil edilmedi." % DEFAULT_SECTIONS[key])
			continue
		register_section(key, provider)


## B4: offline kazanc. EN SON kaydedilmeli: deserialize sirasinda saved_at okunur,
## kazanc ise post_load'da (tum parcalar ve Economy.refresh'ten sonra) verilir.
func _register_offline_progress() -> void:
	var offline: Node = OfflineProgressScript.new()
	add_child(offline)
	register_section(&"offline", offline)
	# Kazanc verilince hemen kaydet: saved_at guncellensin, ayni sure tekrar odenmesin.
	offline.offline_earnings_granted.connect(_on_offline_earnings_granted)


func _on_offline_earnings_granted(_earned: Variant, _away_seconds: float) -> void:
	save_game()


func _tmp_path() -> String:
	return save_path + ".tmp"


func _backup_path() -> String:
	return save_path + ".bak"


func _corrupt_path() -> String:
	return save_path.get_basename() + ".corrupt.json"
