# Windows build ve test rehberi (A8)

Güncel hedef **yalnızca Windows (PC)**. Kullanıcının 29 Ekim 2026 tarihli kapsam düzeltmesi, eski GitHub görevlerindeki Android + Windows gereksinimlerinin yerine geçer. Mobil yayın, Android export'u ve telefon testleri teslim koşulu değildir. Mevcut genel dokunmatik uyumluluğu kalabilir; bu bir mobil sürüm taahhüdü değildir.

Motor: **Godot 4.7.2**, GL Compatibility renderer.

## 1. Çalıştırma

1. Godot 4.7.2 ile `project.godot` dosyasını içe aktar.
2. Ana sahne `main.tscn` olarak ayarlıdır. **F5** ile çalıştır.
3. İlk içe aktarmada üretilen `.gd.uid` dosyalarını kaynak kontrolüne ekle. `.godot/` önbelleği eklenmez.

Yıldıza sol tıklamak para kazandırır. Orta veya sağ fare tuşuyla sürüklemek kamerayı yıldız çevresinde çevirir; fare tekerleği yakınlığı değiştirir. **Ortala** başlangıç görünümüne döner. Debug sürümde **F1** geliştirici araçlarını açar.

## 2. Kayıttan yalıtılmış testler

Python ve Godot ile proje kökünden:

```text
python game/tests/verify.py --engine "GODOT_EXE_YOLU"
python game/tests/verify.py --engine "GODOT_EXE_YOLU" --visual
```

İlk komut testleri görüntü penceresi olmadan çalıştırır. `--visual`, gerçek grafik penceresinde oyun akışını da doğrular ve ekran görüntüsü/performans kaydı üretir.

Araç, projenin yanında `.verification/project` içinde ayrı bir kopya oluşturur. Windows'ta test alt süreçlerinin `APPDATA` ve `LOCALAPPDATA` yollarını bu alana yönlendirir. Gerçek oyuncu kaydı okunmaz veya üzerine yazılmaz. Çıkış kodu **0** başarı, **1** başarısızlık anlamına gelir. Ayrıntılı sonuçlar `.verification/` altında, görüntüler ve `desktop-profile.json` ise `.verification/project/screenshots/` altındadır.

Yalnızca ilgili akışı tekrar çalıştırmak için:

```text
python game/tests/verify.py --engine "GODOT_EXE_YOLU" --visual --gameplay-only
python game/tests/verify.py --engine "GODOT_EXE_YOLU" --visual --camera-only
```

Doğrudan autoload testleri, sınıf önbelleği içe aktarılmış projede runner sahnesiyle çalışır:

```text
godot --headless --path . res://tests/runner.tscn -- res://tests/economy_test.gd
godot --headless --path . res://tests/runner.tscn -- res://tests/save_integration_test.gd
```

Bu doğrudan komutlar yalıtılmış test kopyası oluşturmaz; normal geliştirme için `verify.py` tercih edilir. Denge simülasyonu: `python tools/balance_sim.py`.

## 3. Windows release export'u

**Durum:** Editörde çalıştırma ve Windows testleri doğrulandı. Windows release export'u henüz doğrulanmadı ve `export_presets.cfg` henüz mevcut değil. Aşağıdaki adımlar tamamlanmadan dağıtılabilir `.exe` hazır sayılmaz.

1. **Editor > Manage Export Templates > Download and Install** ile editörle aynı sürümdeki **4.7.2** export şablonlarını kur.
2. **Project > Export > Add... > Windows Desktop** seç.
3. Export Path: `build/windows/IdleGameGodot.exe`. `build/` çıktıları kaynak kontrolüne eklenmez.
4. İsteğe bağlı **Embed PCK**, verileri tek `.exe` içinde paketler.
5. Release için **Export With Debug** seçeneğini kapatıp **Export Project** çalıştır.
6. Çıkan `.exe` ile kayıt/yükleme, satın alma ve kamera kontrollerini dene. F1 ve gizli köşe girişinin geliştirici paneli açmadığını doğrula.

Godot'un ürettiği `export_presets.cfg` takımın ortak Windows ayarları için kaynak kontrolüne eklenir. Kimlik bilgileri `export_credentials.cfg` içinde tutulur ve kaynak kontrolüne eklenmez.

## 4. Birleştirme ve dağıtım kontrolleri

- Windows'ta proje açılır; beklenmedik derleme veya çalışma hatası yoktur.
- Değişiklikle ilgili test grupları geçer.
- Grafik penceresinde fare, kamera, mağaza ve farklı pencere oranları doğrulanır.
- Release dağıtımından önce Windows export'u ve debug araçlarının kapalı oluşu ayrıca doğrulanır.
- Mobil cihaz veya Android build kontrolü aranmaz.
