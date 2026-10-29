class_name OrbiterData
extends Resource
## Bir orbiter türünün EKONOMİ verisi (A4). Yeni orbiter = data/orbiters/ altına yeni .tres, kod değişmez.
## Görsel veri ayrı: game/visuals/ (Bozhan), aynı `id` ile eşleşir.
## Sayılar float: .tres içinde bilimsel gösterim kullanılabilir (örn. 1.5e12).

## Benzersiz kimlik (snake_case). Görsel .tres, kayıt ve Economy bununla eşleşir.
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## İlk adedin maliyeti.
@export var base_cost: float = 10.0
## n. adedin maliyeti = base_cost * cost_growth^n (sahip olunan adet n).
@export var cost_growth: float = 1.15
## Tek adedin saniyelik geliri (upgrade çarpanları hariç).
@export var base_income: float = 1.0
