extends RefCounted
## B5 (#14). Yorunge konum matematigi, SAF fonksiyonlar (node/engine gerektirmez, headless test edilir).
## OrbitManager bunu kullanir. class_name KULLANMA: preload ile yuklenir.
##
## MultiMesh 3D buffer duzeni (instance basina 12 float, 3x4 matrisin satirlari):
##   [bx.x, by.x, bz.x, ox,  bx.y, by.y, bz.y, oy,  bx.z, by.z, bz.z, oz]
## Biz sadece tekduze olcek kullaniriz: kosegen = olcek, konum = 3, 7, 11. Olcek bir kez yazilir,
## her karede sadece uc konum degeri guncellenir.

const FLOATS_PER_INSTANCE: int = 12
const OFFSET_X: int = 3
const OFFSET_Y: int = 7
const OFFSET_Z: int = 11

## Kapasite en az bu kadar acilir (kucuk sayilarda tekrar tekrar buyutmeyelim).
const MIN_CAPACITY: int = 16

## Dusuk uyusmazlikli diziler: ayni indeks her zaman ayni yaricap/faza gider (yeni orbiter eskileri oynatmaz),
## ve yaricap ile faz birbirine baglanmaz (bant ici duzgun dagilir, belirgin desen olusmaz).
const _GOLDEN: float = 0.6180339887498949
const _PLASTIC: float = 0.7548776662466927


## i. orbiter'in yaricapi: [center - spread/2, center + spread/2] bandi icinde duzgun dagilir.
static func band_radius(index: int, center: float, spread: float) -> float:
	return center - spread * 0.5 + spread * fposmod(float(index) * _GOLDEN, 1.0)


## i. orbiter'in baslangic acisi (radyan, [0, TAU)).
static func start_phase(index: int) -> float:
	return TAU * fposmod(float(index) * _PLASTIC, 1.0)


## Gereken sayi mevcut kapasiteyi asarsa 2 kati buyutur (en az MIN_CAPACITY), limit'i asmaz.
## Gereken sayi sigiyorsa kapasite degismez.
static func next_capacity(needed: int, current: int, limit: int) -> int:
	if needed <= current:
		return current
	var capacity: int = maxi(current, MIN_CAPACITY)
	while capacity < needed:
		capacity *= 2
	return mini(capacity, limit)


## [from_index, to_index) araligina tekduze olcek matrisi yazar (konum 0).
static func init_scale(buffer: PackedFloat32Array, from_index: int, to_index: int, scale: float) -> void:
	for i: int in range(from_index, to_index):
		var base: int = i * FLOATS_PER_INSTANCE
		buffer[base] = scale
		buffer[base + 1] = 0.0
		buffer[base + 2] = 0.0
		buffer[base + OFFSET_X] = 0.0
		buffer[base + 4] = 0.0
		buffer[base + 5] = scale
		buffer[base + 6] = 0.0
		buffer[base + OFFSET_Y] = 0.0
		buffer[base + 8] = 0.0
		buffer[base + 9] = 0.0
		buffer[base + 10] = scale
		buffer[base + OFFSET_Z] = 0.0


## Ilk `count` orbiter'in konumunu yerinde (allocation yok) gunceller.
## Yorunge XZ duzleminde bir cemberdir, duzlem X ekseni etrafinda `inclination` kadar egilir
## (incl_sin / incl_cos onceden hesaplanip verilir).
static func update_positions(
		buffer: PackedFloat32Array,
		count: int,
		radii: PackedFloat32Array,
		phases: PackedFloat32Array,
		time: float,
		angular_speed: float,
		incl_sin: float,
		incl_cos: float) -> void:
	var angle_offset: float = angular_speed * time
	for i: int in count:
		var angle: float = phases[i] + angle_offset
		var radius: float = radii[i]
		var along: float = sin(angle) * radius
		var base: int = i * FLOATS_PER_INSTANCE
		buffer[base + OFFSET_X] = cos(angle) * radius
		buffer[base + OFFSET_Y] = along * incl_sin
		buffer[base + OFFSET_Z] = along * incl_cos


## Buffer'dan i. instance'in konumunu okur (debug paneli ve testler icin).
static func position_at(buffer: PackedFloat32Array, index: int) -> Vector3:
	var base: int = index * FLOATS_PER_INSTANCE
	return Vector3(buffer[base + OFFSET_X], buffer[base + OFFSET_Y], buffer[base + OFFSET_Z])
