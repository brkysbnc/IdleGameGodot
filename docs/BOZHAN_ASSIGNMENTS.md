# Bozhan'ın assignment durumu — 29 Ekim 2026

Çalışma dalı: `feature/b7-b10-gameplay`. Bu belge, 29 Ekim 2026'da kullanıcı tarafından onaylanan entegrasyonun uygulama ve doğrulama kaydıdır. Nihai dal ve PR durumu GitHub üzerinden izlenir.

**Güncel platform kapsamı: yalnızca Windows (PC).** Kullanıcının 29 Ekim 2026 tarihli düzeltmesi, eski GitHub görevlerindeki Android + Windows hedefinin yerine geçer. Mobil yayın, Android export'u ve fiziksel telefon testleri tamamlanma koşulu değildir. Mevcut genel dokunmatik uyumluluğu kalabilir; mobil sürüm sözü verilmez. Son polish aşaması bu entegrasyondan sonra ele alınacak.

## Devralınan kod

Başlangıç, Berkay'ın A zincirini içeren `fix/godot-verified-fixes` dalının `21fd39a` sürümüdür. Mevcut B kodu, dal geçmişlerini birleştirmeden dosya olarak çalışma alanına alındı:

- B1–B4: `feature/b4-offline-progress` / `2b55811`.
- B5–B6: `feature/b5-orbit-motor` / `3e88f57`.

İlk dosya aktarımının ardından özgün B1–B4 ve B5–B6 commit geçmişleri de birleştirme adayına alındı (`84fa515`, `648e464`). Bu geçmiş birleştirmeleri, test edilen oyun dosyalarının içeriğini değiştirmedi.

B3'ün yeni testlerinde `OrderedProvider`, yalnızca `Provider` kabul eden yardımcıya verildiği için derleme hatası vardı. Yardımcı, gerçek kayıt arayüzünün kabul ettiği `Object` tipine düzeltildi. Test çalıştırıcısı da derlenemeyen bir script için açık hata koduyla çıkar; süresiz açık kalmaz.

## Görevler

| Görev | Uygulama | Doğrulama |
|---|---|---|
| B1 / #10 | Tüm yükseltme türleri, önbellek, kayıt desteği devralındı. | UpgradeSystem ve gerçek Economy testleri geçiyor. |
| B2 / #11 | Sabit tick, kesirli oran, otomatik tıklama devralındı. | AutoClicker testleri geçiyor. |
| B3 / #12 | JSON, sürüm, yedek, atomik yazma ve yaşam döngüsü kayıtları devralındı. | 37 kayıt kontrolü ve gerçek kayıt/gelir entegrasyonu geçiyor. |
| B4 / #13 | Çevrimdışı gelir, 8 saat sınırı, saat geri alma koruması ve özet devralındı. | OfflineProgress testleri geçiyor. Telefon doğrulaması PC kapsamının dışında. |
| B5 / #14 | MultiMesh yörünge motoru devralındı. | Birim testleri ve 500 nesneyle Windows ölçümü geçti. |
| B6 / #15 | Beş nesne türünün görsel verisi devralındı. | Veri doğrulama, kimlik eşleşmesi ve yörünge testleri geçiyor. |
| B7 / #16 | `main.tscn`, kamera, yıldız, tıklama, panorama galaksi, ortak güvenli alan ve tek mesh yörünge çizgileri eklendi. | Gerçek pencere üzerinden yıldız tıklaması, boş alan ve mağaza giriş ayrımı; üç ekran oranında kamera sınırları geçiyor. |
| B8 / #17 | Sinyalle güncellenen 10 Hz HUD, sabit havuzlu kazanç yazıları ve parçacıklar, yıldız darbesi eklendi. | 50 sinyalin tek HUD güncellemesinde birleşmesi ve 200 tıklamada havuzun büyümemesi doğrulandı. |
| B9 / #18 | Mevcut mağaza ana sahnede sağa yerleştirildi; satın alma, gelir ve görseller bağlandı. | Gerçek mağaza düğmesi, yükseltme ve açılır menü akışı; 16:9, 20:9 ve 4:3 yerleşimleri geçiyor. |
| B10 / #19 | F1 / beş köşe dokunuşu, para ekleme, gerçek ×10 simülasyon, onaylı sıfırlama, 500 nesne kurulumu, ses ve kamera hareketi eklendi. | Debug işlemleri ve kayıt sıfırlamasında görsellerin temizlenmesi geçiyor. Windows release oluşturma ve release korumalarının doğrulaması bekliyor. |

## Çalıştırma

Godot 4.7.2 ile `project.godot` dosyasını içe aktar ve F5'e bas. Ana sahne `main.tscn` olarak kayıtlıdır. Proje ayarındaki diğer ekleme, dokunmanın fareye bir kez çevrilmesini açıkça belirtir. Berkay'ın mağaza ve ekonomi kaynaklarında değişiklik yapılmadı.

- Yıldıza sol tıkla: yıldız tozu kazan.
- Sağdaki listelerden gök cismi ve yükseltme satın al.
- Orbiter'a özel yükseltmeler için sağ üstteki **Yükseltmeler** düğmesini kullan.
- **Ses: açık/kapalı** düğmesi sesleri değiştirir.
- Oyun alanında **orta veya sağ fare tuşunu basılı tutup sürükle**: yıldız çevresinde kamerayı çevir. Yatay ve dikey dönüş tam turdur; yıldız merkezde kalır.
- **Fare tekerleği**: yakınlaş/uzaklaş. **Ortala**: başlangıç açısına ve yakınlığına dön.
- Mevcut dokunmatik uyumluluğunda tek parmakla dönüş ve iki parmakla yakınlaşma da bulunur. Bu uyumluluk, mobil yayın hedefi anlamına gelmez.
- Debug sürümde **F1** veya başlığın sol üst köşesine beş hızlı dokunuş araçları açar. Release sürümde panel ve gizli düğme oluşturulmaz; işlemler ayrıca `OS.is_debug_build()` ile korunur.

×10 modu, gerçek zamanı kullanan Economy'yi de hızlandırmak için ek ekonomi ve otomatik tıklama adımları yürütür; yalnızca animasyon hızını değiştirmez. Sıfırlama düğmesi uygulama içinde onay ister ve yalnızca debug sürümde kullanılabilir.

### Ek istek: yıldız merkezli serbest kamera

Kamera kontrolü, kullanıcının oyun testi sırasında istediği ek özelliktir. GitHub'daki B7 kamera kurulumunu, B10 hafif kamera hareketini kapsar; Blender benzeri serbest yörünge kontrolü açıkça tanımlı değildi. Bu istek B7'nin yerel uygulamasına eklendi, Berkay'ın görevlerine veya GitHub görev tanımlarına yazılmadı.

`game/orbit_camera.gd` kamera yönünü quaternion ile tutar. Kutup noktalarından geçerken kamera bozulmaz; yıldız sabit hedef olarak kalır. Ekran boyutu değiştiğinde açı ve göreli yakınlık korunur. Görünüm değiştikçe yıldızın dokunma alanı yenilenir. Mağazanın girişleri kamerayı etkilemez. Parmağın kaydırma hareketi, yıldızı tıklamaktan ayrılır; Godot'un ürettiği ek fare olayları ikinci gelir oluşturmaz.

Kamera için ayrı test (`game/tests/orbit_camera_test.gd`) **100 kontrol** içerir. Ana sahne testi gerçek giriş yönlendirmesiyle fare dönüşü, tekerlek, ortalama, mağaza ayrımı, dokunma/sürükleme/iki parmak hareketlerini de kontrol eder. Odaklı çalıştırma:

Son grafik penceresi doğrulaması: **4/4 test grubu**, **100 kamera kontrolü** ve **76 oyun akışı kontrolü**, sıfır hata. Windows kapsamı için telefon doğrulaması aranmaz.

```text
python game/tests/verify.py --engine "GODOT_EXE_YOLU" --visual --camera-only
```

## Tekrarlanabilir testler

Python ve Godot ile:

```text
python game/tests/verify.py --engine "GODOT_EXE_YOLU"
python game/tests/verify.py --engine "GODOT_EXE_YOLU" --visual --gameplay-only
```

Araç, projenin yanında `.verification/project` içinde ayrı bir kopya oluşturur. Windows'ta `APPDATA` ve `LOCALAPPDATA` yalnızca test alt süreçleri için bu klasörün içine yönlendirilir. Gerçek oyuncu kaydı okunmaz veya üzerine yazılmaz. Test kopyası Git çalışma alanından ayrıdır.

Birleştirme öncesi Windows doğrulamasında, içe aktarma ve gerçek grafik penceresi dahil **17/17 test grubu geçti**. Kamera testi **100 kontrol**, ana oyun akışı **76 kontrol**, sıfır hata verdi. Mevcut kayıt testindeki beklenen bozuk veri reddetme mesajları, test aracında açıkça tanımlı istisnalardır; beklenmedik derleme, çalışma veya çizim hataları testi başarısız sayar.

Ekran görüntüleri: `.verification/project/screenshots/`. Ayrı `desktop-profile.json`, 500 nesnenin çizildiği 120 karelik ölçümü, ekran kartını ve ortalama FPS'yi kaydeder. Windows / OpenGL Compatibility / RTX 3060 üzerinde yaklaşık **60 FPS** ölçüldü.

## Dağıtımdan önce kalan Windows doğrulaması

- Windows release export'u ve release sürümde debug araçlarının bulunmaması. A8 / #21'in Windows export hattı henüz tamamlanmadı; Android kısmı güncel kapsamın dışında.
- Onaylanan entegrasyonun PR değerlendirmesi ve merge sonucu ayrıca doğrulanır. Bu belge merge işleminin tamamlandığını ilan etmez.
- Mobil test veya Android export bekleyen bir tamamlanma koşulu kalmadı. Polish çalışması bu hazırlık değişikliğine dahil edilmedi.
