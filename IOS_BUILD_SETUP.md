# iOS Build Setup - Uyarıları Giderme

## Yapılan Değişiklikler

Podfile güncellendi ve yaygın iOS build uyarılarını azaltmak için ayarlar eklendi:
- iOS platform versiyonu belirtildi (13.0)
- Deprecated API uyarıları bastırıldı
- Module map ve umbrella header uyarıları bastırıldı
- Swift versiyonu belirtildi

## Adımlar

### 1. CocoaPods Bağımlılıklarını Güncelle

Terminal'de şu komutu çalıştır:

```bash
cd ios
pod install
```

Eğer hata alırsan, şunu dene:

```bash
cd ios
pod deintegrate
pod install
```

### 2. Xcode'da Build Al

Xcode'da projeyi aç:
```bash
open ios/Runner.xcworkspace
```

**ÖNEMLİ:** `.xcodeproj` değil, `.xcworkspace` dosyasını açmalısın!

### 3. Kalan Uyarıları Kontrol Et

Eğer hala uyarılar varsa, Xcode'da:
1. Product → Clean Build Folder (⇧⌘K)
2. Product → Build (⌘B)

### 4. Uyarıları Bastırma (Opsiyonel)

Eğer belirli uyarıları bastırmak istersen, Xcode'da:
1. Project Navigator'da Runner projesini seç
2. Build Settings sekmesine git
3. "All" ve "Combined" seçeneklerini aç
4. Arama kutusuna "warning" yaz
5. İlgili uyarı ayarlarını düzenle

## Yaygın Uyarılar ve Çözümleri

### Deprecated API Uyarıları
- Podfile'da zaten bastırıldı (`GCC_WARN_DEPRECATED_FUNCTIONS = NO`)

### Module Map Uyarıları
- Podfile'da zaten bastırıldı (`CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = NO`)

### Swift Versiyon Uyarıları
- Podfile'da Swift 5.0 belirtildi

### Minimum Deployment Target Uyarıları
- Podfile'da iOS 13.0 belirtildi

## Hala Sorun Varsa

Eğer 54 uyarıdan çoğu hala görünüyorsa, Xcode'daki uyarı mesajlarını paylaşabilirsin. Böylece daha spesifik çözümler sunabilirim.
