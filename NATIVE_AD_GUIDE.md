# Daro Flutter SDK - 네이티브 광고 구현 가이드

## 개요

Daro Flutter SDK는 개발자가 자유롭게 네이티브 광고 레이아웃을 디자인할 수 있는 기능을 제공합니다.
Flutter의 `FLTNativeAdFactory` (iOS) 또는 `PlatformViewFactory` (Android)를 알 필요 없이,
**Daro만의 추상화된 인터페이스**를 사용합니다.

---

## iOS 구현 (Swift)

### Step 1: 네이티브 팩토리 구현

```swift
// iOS/Runner/MyNativeAdFactory.swift
import UIKit
import daro_flutter

class MyNativeAdFactory: NSObject, DaroNativeAdFactory {
    func createNativeAdView() -> UIView {
        // 방법 1: 프로그래밍 방식으로 뷰 생성
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.clipsToBounds = true

        // Icon ImageView
        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 8
        iconImageView.clipsToBounds = true
        iconImageView.tag = 1

        // Title Label
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.numberOfLines = 2
        titleLabel.tag = 2

        // Body Label
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        bodyLabel.numberOfLines = 2
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.tag = 3

        // CTA Button
        let ctaButton = UIButton()
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.backgroundColor = .systemBlue
        ctaButton.layer.cornerRadius = 8
        ctaButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        ctaButton.tag = 4

        // Media View
        let mediaView = UIView()
        mediaView.backgroundColor = .systemGray6
        mediaView.layer.cornerRadius = 8
        mediaView.tag = 5

        // Advertiser Label
        let advertiserLabel = UILabel()
        advertiserLabel.font = .systemFont(ofSize: 13, weight: .regular)
        advertiserLabel.textColor = .secondaryLabel
        advertiserLabel.tag = 6

        // Layout
        [iconImageView, titleLabel, advertiserLabel, mediaView, bodyLabel, ctaButton]
            .forEach {
                view.addSubview($0)
                $0.translatesAutoresizingMaskIntoConstraints = false
            }

        NSLayoutConstraint.activate([
            // Icon (상단 좌측)
            iconImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            iconImageView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 12),
            iconImageView.heightAnchor.constraint(equalToConstant: 56),
            iconImageView.widthAnchor.constraint(equalToConstant: 56),

            // Title (Icon 우측)
            titleLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor),
            titleLabel.leftAnchor.constraint(equalTo: iconImageView.rightAnchor, constant: 12),
            titleLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -12),

            // Advertiser (Title 하단)
            advertiserLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            advertiserLabel.leftAnchor.constraint(equalTo: iconImageView.rightAnchor, constant: 12),
            advertiserLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -12),

            // Media View (Icon 하단)
            mediaView.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            mediaView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 12),
            mediaView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -12),
            mediaView.heightAnchor.constraint(equalToConstant: 180),

            // Body (Media View 하단)
            bodyLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 12),
            bodyLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 12),
            bodyLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -12),

            // CTA Button (하단)
            ctaButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
            ctaButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 12),
            ctaButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -12),
            ctaButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            ctaButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        return view

        // 방법 2: XIB에서 로드 (권장)
        // return Bundle.main.loadNibNamed("MyNativeAd", owner: nil)!.first as! UIView
    }

    func bindAdData(_ view: UIView, ad: Any) {
        // DaroAdNative 타입으로 캐스팅
        guard let nativeAd = ad as? DaroAdNative else { return }

        // UI 요소에 광고 데이터 바인딩
        (view.viewWithTag(1) as? UIImageView)?.image = nativeAd.icon as? UIImage
        (view.viewWithTag(2) as? UILabel)?.text = nativeAd.title
        (view.viewWithTag(3) as? UILabel)?.text = nativeAd.body
        (view.viewWithTag(4) as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        (view.viewWithTag(6) as? UILabel)?.text = nativeAd.advertiser

        // Media View는 Daro SDK에서 자동 처리됨
        if let mediaView = view.viewWithTag(5) {
            if let mediaContent = nativeAd.mediaContent {
                // Daro SDK의 미디어 컨텐츠 설정
                // (내부적으로 AdMob/AppLovin의 MediaView 처리)
            }
        }
    }
}
```

### Step 2: AppDelegate에서 팩토리 등록

```swift
// iOS/Runner/AppDelegate.swift
import UIKit
import Flutter
import daro_flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 네이티브 광고 팩토리 등록
    DaroFlutterPlugin.registerNativeAdFactory(
      MyNativeAdFactory(),
      factoryId: "my_native_ad_layout"
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Step 3: Flutter에서 사용

```dart
// lib/main.dart
import 'package:daro_flutter/daro_flutter.dart';
import 'package:flutter/material.dart';

class NativeAdExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('네이티브 광고')),
      body: Center(
        child: DaroNativeAdWidget(
          factoryId: 'my_native_ad_layout',  // iOS에서 등록한 ID
          adUnitId: '2f83504a-fd64-47d2-a70d-1eadaaeb04a6',  // iOS 광고 ID
          width: 350,
          height: 400,
          onAdLoaded: () => print('광고 로드 성공'),
          onAdFailedToLoad: (error) => print('광고 로드 실패: $error'),
          onAdClicked: () => print('광고 클릭'),
          onAdImpression: () => print('광고 노출'),
        ),
      ),
    );
  }
}
```

---

## Android 구현 (Kotlin)

### Step 1: XML 레이아웃 작성

```xml
<!-- android/app/src/main/res/layout/my_native_ad.xml -->
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="400dp"
    android:padding="0dp">

    <androidx.cardview.widget.CardView
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        app:cardCornerRadius="12dp"
        app:cardElevation="4dp">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="match_parent"
            android:orientation="vertical"
            android:padding="12dp">

            <!-- Header: Icon + Title + Advertiser -->
            <LinearLayout
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:orientation="horizontal">

                <ImageView
                    android:id="@+id/ad_app_icon"
                    android:layout_width="56dp"
                    android:layout_height="56dp"
                    android:scaleType="centerCrop"
                    android:background="@android:color/darker_gray" />

                <LinearLayout
                    android:layout_width="0dp"
                    android:layout_height="wrap_content"
                    android:layout_weight="1"
                    android:layout_marginStart="12dp"
                    android:orientation="vertical">

                    <TextView
                        android:id="@+id/ad_headline"
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:textSize="16sp"
                        android:textStyle="bold"
                        android:maxLines="2"
                        android:ellipsize="end" />

                    <TextView
                        android:id="@+id/ad_advertiser"
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:textSize="13sp"
                        android:textColor="#666666"
                        android:layout_marginTop="4dp" />
                </LinearLayout>
            </LinearLayout>

            <!-- Media View -->
            <FrameLayout
                android:id="@+id/ad_media"
                android:layout_width="match_parent"
                android:layout_height="180dp"
                android:layout_marginTop="12dp"
                android:background="@android:color/darker_gray" />

            <!-- Body -->
            <TextView
                android:id="@+id/ad_body"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginTop="12dp"
                android:textSize="14sp"
                android:maxLines="2"
                android:ellipsize="end" />

            <!-- CTA Button -->
            <Button
                android:id="@+id/ad_call_to_action"
                android:layout_width="match_parent"
                android:layout_height="44dp"
                android:layout_marginTop="12dp"
                android:textSize="16sp"
                android:textStyle="bold" />

        </LinearLayout>
    </androidx.cardview.widget.CardView>
</FrameLayout>
```

### Step 2: 네이티브 팩토리 구현

```kotlin
// android/app/src/main/kotlin/.../MyNativeAdFactory.kt
import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import droom.daro.core.model.DaroAdNative
import so.daro.flutter.native.DaroNativeAdFactory

class MyNativeAdFactory(
    private val context: Context
) : DaroNativeAdFactory {

    override fun createNativeAdView(): View {
        // XML에서 레이아웃 inflate
        return LayoutInflater.from(context).inflate(
            R.layout.my_native_ad,
            null
        )
    }

    override fun bindAdData(view: View, ad: DaroAdNative) {
        // UI 요소에 광고 데이터 바인딩
        view.findViewById<TextView>(R.id.ad_headline)?.text = ad.title
        view.findViewById<TextView>(R.id.ad_body)?.text = ad.body
        view.findViewById<TextView>(R.id.ad_advertiser)?.text = ad.advertiser
        view.findViewById<Button>(R.id.ad_call_to_action)?.text = ad.callToAction

        // 아이콘 이미지 설정
        ad.icon?.let { icon ->
            view.findViewById<ImageView>(R.id.ad_app_icon)?.setImageBitmap(icon)
        }

        // Media View는 Daro SDK에서 자동 처리됨
        val mediaView = view.findViewById<FrameLayout>(R.id.ad_media)
        ad.mediaContent?.let { mediaContent ->
            // Daro SDK의 미디어 컨텐츠 설정
            // (내부적으로 AdMob/AppLovin의 MediaView 처리)
        }
    }
}
```

### Step 3: MainActivity에서 팩토리 등록

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import so.daro.flutter.DaroFlutterPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 네이티브 광고 팩토리 등록
        DaroFlutterPlugin.registerNativeAdFactory(
            MyNativeAdFactory(this),
            "my_native_ad_layout"
        )
    }
}
```

### Step 4: Flutter에서 사용

```dart
// lib/main.dart
import 'package:daro_flutter/daro_flutter.dart';
import 'package:flutter/material.dart';

class NativeAdExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('네이티브 광고')),
      body: Center(
        child: DaroNativeAdWidget(
          factoryId: 'my_native_ad_layout',  // Android에서 등록한 ID
          adUnitId: '5fb79bb3-4874-4ed8-afaa-b3e6eb24e0fa',  // Android 광고 ID
          width: 350,
          height: 400,
          onAdLoaded: () => print('광고 로드 성공'),
          onAdFailedToLoad: (error) => print('광고 로드 실패: $error'),
          onAdClicked: () => print('광고 클릭'),
          onAdImpression: () => print('광고 노출'),
        ),
      ),
    );
  }
}
```

---

## 플랫폼별 광고 ID 자동 선택

```dart
import 'dart:io';
import 'package:daro_flutter/daro_flutter.dart';
import 'package:flutter/material.dart';

class NativeAdExample extends StatelessWidget {
  // 플랫폼별 광고 ID
  static const String _iosAdUnitId = '2f83504a-fd64-47d2-a70d-1eadaaeb04a6';
  static const String _androidAdUnitId = '5fb79bb3-4874-4ed8-afaa-b3e6eb24e0fa';

  String get _adUnitId {
    if (Platform.isIOS) {
      return _iosAdUnitId;
    } else if (Platform.isAndroid) {
      return _androidAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('네이티브 광고')),
      body: Center(
        child: DaroNativeAdWidget(
          factoryId: 'my_native_ad_layout',
          adUnitId: _adUnitId,  // 플랫폼별 자동 선택
          width: 350,
          height: 400,
          onAdLoaded: () => print('광고 로드 성공'),
          onAdFailedToLoad: (error) => print('광고 로드 실패: $error'),
        ),
      ),
    );
  }
}
```

---

## 핵심 장점

### 1. Flutter 인터페이스 완전 숨김
- ✅ 개발자는 `FLTNativeAdFactory` (iOS) 몰라도 됨
- ✅ 개발자는 `PlatformViewFactory` (Android) 몰라도 됨
- ✅ Daro만의 `DaroNativeAdFactory` 인터페이스만 사용

### 2. AdMob보다 단순한 API
```
AdMob: FLTNativeAdFactory (10+ 메서드) vs Daro: DaroNativeAdFactory (2 메서드)
```

### 3. 자유로운 레이아웃
- ✅ XIB/Storyboard (iOS) 지원
- ✅ XML 레이아웃 (Android) 지원
- ✅ 프로그래밍 방식 레이아웃 지원

### 4. Daro SDK 기능 활용
- ✅ AdMob/AppLovin 미디에이션 자동 처리
- ✅ 광고 로드/노출/클릭 이벤트 자동 추적
- ✅ 기존 Daro SDK API 완전 호환

---

## 문제 해결

### iOS: 모듈을 찾을 수 없음
```swift
// iOS/Runner/AppDelegate.swift 상단에 추가
import daro_flutter
```

### Android: 클래스를 찾을 수 없음
```kotlin
// android/app/build.gradle에 추가
dependencies {
    implementation project(':daro_flutter')
}
```

### 광고가 로드되지 않음
1. Daro SDK 초기화 확인: `DaroFlutter.initialize()`
2. 광고 ID 확인
3. 네트워크 연결 확인
4. 로그 확인: `onAdFailedToLoad` 콜백

---

## 참고 자료

- [Daro SDK 문서](https://docs.daro.so)
- [Flutter Platform Views](https://docs.flutter.dev/platform-integration/platform-views)
- [AdMob 네이티브 광고 가이드](https://developers.google.com/admob/flutter/native)
