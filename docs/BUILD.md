# Build ve test rehberi (A8)

Hedef platformlar: **Windows (PC)** ve **Android (mobil)**. Godot **4.7.2**, GL Compatibility renderer.

## 1. Çalıştırma (geliştirme)

1. Projeyi Godot 4.7.2 ile aç (`project.godot`). İlk açılışta Godot `.godot/` klasörünü ve `.gd.uid` dosyalarını üretir. **`.uid` dosyalarını commit edin**, `.godot/` klasörü commit edilmez.
2. `main.tscn` hazır olunca (B7, #16) Project Settings > Application > Run > Main Scene olarak ayarlanır (`project.godot` Berkay'da).
3. F5 ile çalıştır.

## 2. Testler (komut satırı)

Proje bir kez editörde açılmış ya da `godot --headless --path . --import` ile içe aktarılmış olmalı (sınıf adları ve autoload'lar için).

```
godot --headless --path . --script res://tests/big_number_test.gd
godot --headless --path . --script res://tests/game_data_test.gd
godot --headless --path . --script res://tests/game_state_test.gd
godot --headless --path . --script res://tests/economy_test.gd
godot --headless --path . --script res://tests/shop_panel_test.gd
```

Çıkış kodu 0 = tamam. Bozhan'ın testleri `systems/upgrades/tests/` altında. Dengeyi kontrol etmek için: `python3 tools/balance_sim.py`.

## 3. Export şablonları (bir kez)

Godot'ta **Editor > Manage Export Templates > Download and Install** (editörle **aynı sürüm**: 4.7.2). Şablonlar yüklü değilse export yapılamaz.

## 4. Windows (PC) export

1. **Project > Export > Add... > Windows Desktop**
2. Export Path: `build/windows/IdleGameGodot.exe` (`build/` klasörünü commit etmeyin, `.gitignore`'a eklenmeli)
3. İstersen **Embed PCK** açın (tek dosya `.exe`).
4. **Export Project**. Çıkan `.exe` çift tıkla çalışır.

## 5. Android (mobil) export

### Bir kez kurulum

Godot dokümantasyonuna göre (4.5 sayfası esas alındı, **4.7 sayfasından sürümleri bir kez doğrulayın**: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html>):

| Bileşen | Sürüm |
|---|---|
| JDK | OpenJDK 17 |
| Android SDK Platform-Tools | 35.0.0 veya üstü |
| Android SDK Build-Tools | 35.0.0 |
| Android SDK Platform | Android 35 |
| Command-line Tools | latest |
| CMake | 3.10.2.4988404 |
| NDK | r28b (28.1.13356709) |

Android Studio (SDK Manager) ya da `sdkmanager` ile kurulur. Linux'ta dağıtım paket deposundaki SDK'yı kullanmayın (eski olabilir).

Godot'ta **Editor > Editor Settings > Android**: **Java SDK Path** (JDK 17) ve **Android Sdk Path** (SDK klasörü) ayarlanır.

**Debug keystore** (telefonda deneme için, bir kez):

```
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
```

Oluşan `debug.keystore` dosyasını **repoya koymayın**. Editor Settings > Android > Debug Keystore olarak gösterin (kullanıcı: `androiddebugkey`, parola: `android`).

### Preset

1. **Project > Export > Add... > Android**
2. **Package > Unique Name:** `com.<takim>.idlegame` (ikiniz de aynı adı kullanın, sonradan değiştirmeyin)
3. **Architectures:** `arm64-v8a` açık (modern telefonlar), diğerleri kapalı (daha küçük APK)
4. **Screen > Orientation** projeyle aynı (yatay) zaten `project.godot`'tan gelir
5. Ana ikon: en az 192x192 px (adaptive ikon için 432x432 px ön plan/arka plan)

### Telefonda deneme

1. Telefonda **Geliştirici seçenekleri > USB hata ayıklama** açık, kabloyla bağlı.
2. Godot sağ üstteki **Remote Debug** (Android simgesi) menüsünden telefonu seç, **tek tıkla deploy** ile çalıştır.
3. Ya da **Export Project** ile `.apk` üretip telefona kopyalayıp kurun.

"Could not install to device" hatası: aynı paket adıyla, farklı anahtarla imzalı eski bir sürüm yüklüyse önce onu kaldırın.

### Release (daha sonra)

Release için ayrı bir keystore üretilir (`keytool -v -genkey -keystore ... -alias ... -keyalg RSA -validity 10000`), **Export With Debug** kapatılır. Keystore ve parolaları **asla commit edilmez** (`export_credentials.cfg` zaten `.gitignore`'da). Google Play için AAB gerekir.

## 6. export_presets.cfg

Presetleri editörde bir kez ekledikten sonra Godot **`export_presets.cfg`** dosyasını üretir. Bu dosyayı **commit edin** (iki kişinin aynı preset'i kullanması için). İçinde parola olmaması gerekir, parolalar `export_credentials.cfg`'de tutulur (ignore edilir). Commit etmeden önce dosyada keystore şifresi olmadığını kontrol edin.

## 7. Her PR öncesi kontrol listesi

- [ ] PC'de proje açılıyor, hata/uyarı yok
- [ ] İlgili test script'leri geçiyor
- [ ] Mobil etkisi olan değişiklik telefonda denendi (dokunma, ölçek, performans)
