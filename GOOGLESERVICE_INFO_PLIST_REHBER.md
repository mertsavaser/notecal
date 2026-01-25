# GoogleService-Info.plist Xcode'a Ekleme Rehberi

## 📍 Dosya Konumu
Dosya şu konumda: `ios/Runner/GoogleService-Info.plist`

Ancak Xcode projesine eklenmemiş, bu yüzden Xcode'da görünmüyor.

## ✅ Xcode'da Ekleme Adımları

### Yöntem 1: Drag & Drop (En Kolay)

1. **Finder'ı aç**
   - `ios/Runner/` klasörüne git
   - `GoogleService-Info.plist` dosyasını bul

2. **Xcode'u aç**
   - `Runner.xcworkspace` dosyasını aç (`.xcodeproj` değil!)

3. **Dosyayı sürükle-bırak**
   - Finder'dan `GoogleService-Info.plist` dosyasını tut
   - Xcode'da sol panelde **`Runner`** klasörüne sürükle
   - `Info.plist` dosyasının yanına bırak

4. **Dialog penceresi açılacak:**
   - ✅ **"Copy items if needed"** işaretli olmalı (zaten dosya orada, ama işaretli olsun)
   - ✅ **"Add to targets: Runner"** işaretli olmalı
   - **"Create groups"** seçili olmalı (varsayılan)
   - **"Finish"** butonuna tıkla

5. **Kontrol et:**
   - Sol panelde `Runner` klasöründe `GoogleService-Info.plist` görünmeli
   - Dosyaya tıkla, sağ panelde **"Target Membership"** sekmesinde **"Runner"** işaretli olmalı

### Yöntem 2: File → Add Files to "Runner"

1. **Xcode'da:**
   - Sol üstte **"Runner"** projesini seç
   - Menüden: **File → Add Files to "Runner..."** (veya ⌥⌘A)

2. **Dosya seç:**
   - `ios/Runner/GoogleService-Info.plist` dosyasını seç
   - ✅ **"Copy items if needed"** işaretli olsun
   - ✅ **"Add to targets: Runner"** işaretli olsun
   - **"Create groups"** seçili olsun
   - **"Add"** butonuna tıkla

3. **Kontrol et:**
   - Sol panelde `GoogleService-Info.plist` görünmeli

## 🔍 Doğrulama

### 1. Dosyanın Göründüğünü Kontrol Et
- Xcode'da sol panelde `Runner` klasöründe `GoogleService-Info.plist` görünmeli
- Dosya adı siyah renkte olmalı (gri ise, target'a eklenmemiş demektir)

### 2. Target Membership Kontrolü
- `GoogleService-Info.plist` dosyasına tıkla
- Sağ panelde **"File Inspector"** sekmesine git (en soldaki sekme)
- **"Target Membership"** bölümünde **"Runner"** işaretli olmalı
- İşaretli değilse, işaretle

### 3. Build Settings Kontrolü
- Sol üstte **"Runner"** projesini seç
- **"Build Settings"** sekmesine git
- Arama kutusuna **"GoogleService"** yaz
- Herhangi bir ayar görünmüyorsa normal (Firebase otomatik bulur)

## ⚠️ Önemli Notlar

1. **Workspace kullan:** `.xcodeproj` değil, `.xcworkspace` dosyasını aç
2. **Target Membership:** Dosyanın "Runner" target'ına ekli olduğundan emin ol
3. **Dosya içeriği:** Dosyanın içinde gerçek Firebase değerleri olmalı (placeholder değil)

## 🚀 Sonraki Adımlar

Dosyayı ekledikten sonra:

1. **Clean Build Folder:**
   - Xcode'da: **Product → Clean Build Folder** (⇧⌘K)

2. **Build:**
   - Xcode'da: **Product → Build** (⌘B)

3. **Test:**
   - Uygulamayı çalıştır
   - Firebase hatası artık görünmemeli

## ❓ Sorun Olursa

Eğer dosyayı ekledikten sonra hala Firebase hatası alırsan:

1. **Dosya içeriğini kontrol et:**
   ```bash
   cat ios/Runner/GoogleService-Info.plist
   ```
   - `PROJECT_ID`, `API_KEY`, `BUNDLE_ID` gibi değerler gerçek değerler olmalı

2. **Firebase Console'dan yeni dosya indir:**
   - Firebase Console → Project Settings → iOS app
   - `GoogleService-Info.plist` dosyasını indir
   - Eski dosyayı sil, yenisini ekle

3. **Bundle ID kontrolü:**
   - Xcode'da: Runner → Build Settings → Product Bundle Identifier
   - Firebase Console'daki Bundle ID ile aynı olmalı
