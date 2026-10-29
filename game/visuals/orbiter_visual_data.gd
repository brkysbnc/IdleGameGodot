class_name OrbiterVisualData
extends Resource
## B6 (#15). Bir orbiter turunun GORSEL verisi. Ekonomi verisi data/orbiters/'ta (A), burada sadece gorunum.
## Ikisi ayni `id` ile eslesir: orbiter_id == OrbiterData.id. Ayni .tres'i iki kisi duzenlemez.
## Yeni orbiter = game/visuals/ altina yeni .tres, kod degismez.
##
## Birim: 1 birim = 1 metre. Yildiz orijinde, yorungeler XZ duzleminde (inclination ile egilir).
## Meshler cap'i 1 birim olan kuredir varsayilir, `size` bunu olcekler.

## OrbiterData.id ile birebir ayni olmali (snake_case).
@export var orbiter_id: StringName

## Yorunge bandinin merkez yaricapi (yildizdan uzaklik).
@export_range(1.0, 200.0, 0.1) var orbit_radius: float = 10.0
## Bandin genisligi. Ayni turden orbiter'lar [radius - spread/2, radius + spread/2] icine dagilir.
@export_range(0.0, 50.0, 0.1) var orbit_spread: float = 2.0
## Radyan/sn. Negatif deger ters yone doner.
@export_range(-3.0, 3.0, 0.005) var angular_speed: float = 0.2
## Her orbiter'in cap'i (birim). Kucuk turlerde (toz) cok kucuk, gaz devinde buyuk.
@export_range(0.01, 10.0, 0.01) var size: float = 0.3
## Yorunge duzleminin egimi (derece), ayni tur icin sabit. Turler arasi farkli egim derinlik hissi verir.
@export_range(-90.0, 90.0, 0.5) var inclination_deg: float = 0.0
## Orbiter rengi (doku varsa onunla carpilir).
@export var color: Color = Color.WHITE
## Istege bagli. Bos birakilirsa B5'in paylasilan dusuk poligonlu kuresi kullanilir.
@export var mesh: Mesh
## Istege bagli albedo dokusu.
@export var texture: Texture2D
## Bu turden ekranda en fazla kac orbiter cizilir. Sayi bunu asarsa gelir yine sayilir, sadece gorsel sinirlanir
## (mobil performans hedefi: tur basina 500).
@export_range(1, 2000) var max_instances: int = 500


## Yorungenin ulasabildigi en uzak mesafe (kamera/AABB hesabi icin).
func get_extent() -> float:
	return orbit_radius + orbit_spread * 0.5 + size


## Eksik/mantiksiz veriyi yakalamak icin. Gecerliyse bos dizi, degilse sorun listesi doner.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if orbiter_id == &"":
		problems.append("orbiter_id bos")
	if orbit_radius <= 0.0:
		problems.append("orbit_radius > 0 olmali")
	if orbit_spread < 0.0 or orbit_spread >= orbit_radius * 2.0:
		problems.append("orbit_spread 0 ile 2*orbit_radius arasinda olmali")
	if orbit_radius - orbit_spread * 0.5 <= 0.0:
		problems.append("bandin ic siniri yildizin icine giriyor (radius - spread/2 > 0 olmali)")
	if size <= 0.0:
		problems.append("size > 0 olmali")
	if max_instances < 1:
		problems.append("max_instances >= 1 olmali")
	return problems
