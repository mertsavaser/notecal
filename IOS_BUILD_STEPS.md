# iOS Build - Adım Adım Süreç

## ✅ Tamamlanan Adımlar

1. ✅ Podfile güncellendi (iOS platform versiyonu ve uyarı ayarları eklendi)
2. ✅ `pod install` çalıştırıldı (32 pod yüklendi)

## 📱 Xcode'da Yapılacaklar

### 1. Xcode'u Kapat (Eğer açıksa)
- Xcode'u tamamen kapat (⌘Q)

### 2. Workspace'i Aç
Terminal'de şu komutu çalıştır:
```bash
cd /Users/oykuahmetbeyoglu/Projects/notecal
open ios/Runner.xcworkspace
```

**ÖNEMLİ:** `.xcodeproj` değil, `.xcworkspace` dosyasını açmalısın!

### 3. Xcode'da Clean Build
- Xcode'da: **Product → Clean Build Folder** (veya ⇧⌘K tuşlarına bas)

### 4. Build Al
- Xcode'da: **Product → Build** (veya ⌘B tuşlarına bas)

### 5. Uyarıları Kontrol Et
- Build tamamlandıktan sonra, sol üstteki uyarı sayısını kontrol et
- Artık çok daha az uyarı görmelisin (54'ten çok daha az)

## 🔍 Değişikliklerin Kontrolü

Podfile'daki değişiklikler şu şekilde Xcode'a yansır:

1. **Platform Versiyonu**: Tüm pod'lar artık iOS 13.0 minimum versiyonunu kullanır
2. **Build Settings**: Her pod için uyarı bastırma ayarları uygulanır
3. **Swift Versiyonu**: Tüm pod'lar Swift 5.0 kullanır

Bu ayarlar `Pods` projesinin build settings'inde görünebilir:
- Xcode'da sol panelde "Pods" projesini aç
- Her bir pod target'ının Build Settings'ine bak
- IPHONEOS_DEPLOYMENT_TARGET = 13.0 olmalı

## 🚀 Hızlı Komutlar

Tüm süreci tek seferde yapmak için:

```bash
cd /Users/oykuahmetbeyoglu/Projects/notecal/ios
pod install
cd ..
open ios/Runner.xcworkspace
```

Sonra Xcode'da:
1. ⇧⌘K (Clean Build Folder)
2. ⌘B (Build)

## ❓ Sorun Olursa

Eğer hala çok uyarı varsa:
1. Xcode'da uyarı mesajlarını kontrol et
2. Hangi tür uyarılar olduğunu not et
3. Bana bildir, daha spesifik çözümler sunabilirim
