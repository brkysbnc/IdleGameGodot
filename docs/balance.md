# Denge (A7)

İlk geçiş değerleri. Gerçek oyuncu testlerine göre ayarlanacak. Değerlerin tek kaynağı `data/orbiters/*.tres` ve `data/upgrades/*.tres`, bu belge onlardan üretilmiş özettir (değişince `python3 tools/balance_sim.py` ile yeniden doğrula).

## Formüller (Economy ile aynı)

- Orbiter maliyeti: `base_cost × cost_growth^(sahip olunan adet)`
- Orbiter geliri (saniyede): `base_income × adet × orbiter çarpanı × tüm-orbiter çarpanı × genel çarpan`
- Tık değeri: `1 × tık çarpanı × genel çarpan` (genel gelir upgrade'i tıkı da artırır)
- Otomatik tıklayıcı: saniyede `value` tık ekler, her tık yukarıdaki tık değerini kazandırır
- Upgrade'ler tek seferliktir, çarpanlar birbiriyle çarpılır

## Orbiter'lar

| id | İlk maliyet | Büyüme | Gelir/sn (adet başı) | Geri dönüş (ilk adet) |
|---|---:|---:|---:|---:|
| `dust_cloud` | 15 | 1.15 | 0.1 | 150 sn |
| `asteroid` | 100 | 1.15 | 1 | 100 sn |
| `moon` | 1.500 | 1.16 | 8 | 188 sn |
| `planet` | 40.000 | 1.17 | 47 | 851 sn |
| `gas_giant` | 1.500.000 | 1.18 | 260 | 5769 sn |

## Upgrade'ler

| id | Tür | Hedef | Maliyet | Değer |
|---|---|---|---:|---:|
| `click_power_1` | per_click | - | 150 | 2 |
| `dust_cloud_boost` | orbiter | dust_cloud | 400 | 2 |
| `auto_clicker_1` | auto_click | - | 2.000 | 1 |
| `asteroid_boost` | orbiter | asteroid | 3.000 | 2 |
| `click_power_2` | per_click | - | 25.000 | 2 |
| `moon_boost` | orbiter | moon | 75.000 | 2 |
| `auto_clicker_2` | auto_click | - | 100.000 | 2 |
| `all_income_1` | all_income | - | 750.000 | 1.5 |
| `planet_boost` | orbiter | planet | 2.000.000 | 2 |
| `all_orbiters_1` | all_orbiters | - | 5.000.000 | 2 |
| `gas_giant_boost` | orbiter | gas_giant | 50.000.000 | 2 |

## Hedef tempo ve simülasyon sonucu

`tools/balance_sim.py`, her seferinde en kısa geri dönüşlü şeyi alan, gerçek oyuncudan **daha verimli** bir oyuncuyu simüle eder. Gerçek süreler bundan uzun olur (kabaca 1,5-2 kat). İlk orbiter'ı gerçek oyuncu birkaç saniyede (15 para, 3 tıkla ~5 sn) alır, simülasyon önce tık upgrade'ini aldığı için daha geç gösterir.

| Kilometre taşı | Hedef (gerçek oyuncu) | Simülasyon (3 tık/sn) | Simülasyon (0,5 tık/sn) |
|---|---|---|---|
| İlk Ay | ~5-10 dk | 4 dk 30 sn | 11 dk |
| İlk Gezegen | ~30 dk | 22 dk | 30 dk |
| 10 Ay | ~30 dk | 16 dk | 24 dk |
| İlk Gaz Devi | ~2-4 saat | 2 sa 24 dk | 2 sa 34 dk |
| Tüm upgrade'ler | ~6-10 saat | 4 sa 40 dk | 4 sa 50 dk |
| Her türden 25 adet | ~12-20 saat | 8 sa 03 dk | 8 sa 13 dk |

## Bilinen sınırlar / sonraki adımlar

- Sadece 5 orbiter türü var. Sistemin tavanı birkaç saat ile 1 günlük ilerleme sağlar, daha uzun oyun için yeni orbiter türü ve prestij gibi sistemler gerekir (şimdilik kapsam dışı, YAGNI).
- Tüm sayılar başlangıç tahminidir. Gerçek oyun testinden sonra `.tres` dosyalarında ayarlanır, kod değişmez. Sonra `tools/balance_sim.py` ile tekrar kontrol edin.
- Çevrimdışı kazanç üst sınırı (örn. 8 saat) B4'te (#13) belirlenir, dengeyi etkiler.
