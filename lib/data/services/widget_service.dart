import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:home_widget/home_widget.dart';
import '../../domain/entities/pet.dart';
import '../../core/theme/species_theme.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../core/constants/app_strings.dart';
import '../../presentation/widgets/pixel_pet_image.dart' show pixelKeyFromAssetPath;
import '../../presentation/widgets/pixel_motion_animation.dart'
    show motionSpriteKeyForStage, hiddenPaletteForSpriteKey, dotColorsForKey;

String _colorHex(Color c) =>
    c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();

/// 홈 화면 위젯 서비스
/// 펫 데이터를 홈 화면 위젯에 업데이트하는 서비스
/// 
/// Android와 iOS 홈 화면 위젯에 펫 정보를 표시하기 위해 사용
/// 
/// 중요: 위젯의 상태는 항상 앱 내 펫 상태와 동일해야 합니다.
/// 모든 상태 변경 시 이 서비스를 통해 위젯을 업데이트해야 합니다.
class WidgetService {
  /// 위젯 업데이트 키 상수
  static const String _keyHunger = 'hunger';
  static const String _keyHappiness = 'happiness';
  static const String _keyStamina = 'stamina';
  static const String _keyLevel = 'level';
  static const String _keyExp = 'exp';
  static const String _keyEvolutionStage = 'evolutionStage';
  static const String _keyLastUpdated = 'lastUpdated';
  static const String _keyImageType = 'imageType'; // 펫 이미지 타입 (feed/sleep/exercise/happy/sad)
  static const String _keyImageIndex = 'imageIndex'; // 현재 표시할 이미지 인덱스 (0~3)
  static const String _keyMood = 'mood'; // 펫의 기분 상태 (happy, sleepy, hungry, bored, normal 등)
  static const String _keyMoodText = 'moodText'; // 펫의 기분 상태 한국어 텍스트
  static const String _keyName = 'name'; // 펫의 이름
  static const String _keySyncTraceId = 'syncTraceId'; // 앱-위젯 동기화 추적 ID
  static const String _keyEvolutionType = 'evolutionType'; // 진화 종 (bird/snake/tiger/turtle)
  static const String _keyEvolutionGrade = 'evolutionGrade'; // 등급 (normal/superior/mythical)
  static const String _keyColorVariant = 'colorVariant'; // 일반종 개체 색 변이 (0~3)
  static const String _keyEvolutionImage = 'evolutionImage'; // 진화 이미지 리소스명 (bird1, dragon2 등)
  static const String _keyPixelKey = 'pixelKey'; // 위젯이 도트를 직접 렌더할 스프라이트 키
  // 앱이 계산한 모션 스프라이트 키 + 5색 (위젯이 재계산하지 않고 그대로 사용
  // → 앱과 위젯 렌더가 항상 동일). 색은 ARGB hex 문자열.
  static const String _keyMotionKey = 'motionKey';
  static const String _keyDotDark = 'dotDark';
  static const String _keyDotBody = 'dotBody';
  static const String _keyDotAccent = 'dotAccent';
  static const String _keyDotAccent2 = 'dotAccent2';
  static const String _keyDotAccent3 = 'dotAccent3';

  /// 펫 데이터를 위젯에 업데이트
  /// 
  /// [pet] 업데이트할 펫 엔티티 (앱 내 현재 상태와 동일해야 함)
  /// [imageType] 펫 이미지 타입 (기본값: null, null이면 pet.mood 기반으로 자동 결정)
  /// 
  /// 펫의 상태 정보를 홈 화면 위젯에 전달하여 표시
  /// 
  /// 중요: 이 메서드는 앱 내 펫 상태와 위젯 상태를 동기화합니다.
  /// 모든 상태 변경 후 반드시 호출되어야 합니다.
  Future<void> updatePetWidget(Pet pet, {String? imageType}) async {
    // imageType이 제공되지 않으면 pet.mood 기반으로 자동 결정
    if (imageType == null) {
      final petImageType = getPetImageTypeFromMood(pet.mood);
      imageType = getImageTypeString(petImageType);
    }
    try {
      final syncTraceId = DateTime.now().microsecondsSinceEpoch.toString();

      await HomeWidget.saveWidgetData<String>(_keyHunger, pet.hunger.toString());
      await HomeWidget.saveWidgetData<String>(_keyHappiness, pet.happiness.toString());
      await HomeWidget.saveWidgetData<String>(_keyStamina, pet.stamina.toString());
      await HomeWidget.saveWidgetData<String>(_keyLevel, pet.level.toString());
      await HomeWidget.saveWidgetData<String>(_keyExp, pet.exp.toString());
      await HomeWidget.saveWidgetData<String>(_keyEvolutionStage, pet.evolutionStage.toString());
      await HomeWidget.saveWidgetData<String>(_keyEvolutionGrade, pet.evolutionGrade);
      await HomeWidget.saveWidgetData<String>(_keyColorVariant, pet.colorVariant.toString());

      // 앱과 동일한 모션 스프라이트 키 + 5색을 계산해 넘긴다 (위젯 렌더 통일).
      final motionKey = motionSpriteKeyForStage(
          pet.evolutionType, pet.evolutionStage, pet.evolutionGrade);
      final theme = SpeciesTheme.forType(pet.evolutionType);
      final palette = motionKey == null
          ? null
          : hiddenPaletteForSpriteKey(motionKey, pet.colorVariant);
      final Color dark, body, accent, accent2, accent3;
      if (palette != null && palette.length >= 5) {
        // 설화 영물 — 레퍼런스 5색 팔레트(색변이)
        dark = palette[0];
        body = palette[1];
        accent = palette[2];
        accent2 = palette[3];
        accent3 = palette[4];
      } else {
        // 사신수/털뭉치 — 테마/자연색 (변이). accent2/3는 accent와 동일(3계조)
        final (dot, acc) = dotColorsForKey(
            motionKey ?? 'fluff', pet.evolutionType, theme, pet.colorVariant);
        dark = SpeciesTheme.dotDark;
        body = dot;
        accent = acc;
        accent2 = acc;
        accent3 = acc;
      }
      await HomeWidget.saveWidgetData<String>(_keyMotionKey, motionKey ?? '');
      await HomeWidget.saveWidgetData<String>(_keyDotDark, _colorHex(dark));
      await HomeWidget.saveWidgetData<String>(_keyDotBody, _colorHex(body));
      await HomeWidget.saveWidgetData<String>(_keyDotAccent, _colorHex(accent));
      await HomeWidget.saveWidgetData<String>(_keyDotAccent2, _colorHex(accent2));
      await HomeWidget.saveWidgetData<String>(_keyDotAccent3, _colorHex(accent3));

      await HomeWidget.saveWidgetData<String>(_keyLastUpdated, pet.lastUpdated.toString());
      await HomeWidget.saveWidgetData<String>(_keyImageType, imageType);

      // 진화 이미지 정보 저장 (홈 화면과 동일한 이미지 표시를 위해)
      // mood 이미지를 우선 사용하고, 없으면 기본 진화 이미지로 폴백
      final evolutionImagePath =
          getEvolutionMoodImagePath(pet.evolutionType, pet.evolutionStage, pet.mood)
          ?? getEvolutionImagePath(pet.evolutionType, pet.evolutionStage);
      if (evolutionImagePath != null) {
        // 위젯 도트 렌더용 스프라이트 키 (파일명 stem, 예: 'bird_smile1',
        // '기본이미지', 'dragon2') — 네이티브가 pet_pixel_data.json에서 조회
        await HomeWidget.saveWidgetData<String>(
          _keyPixelKey, pixelKeyFromAssetPath(evolutionImagePath),
        );

        // 폴백용 drawable 리소스명 (도트 JSON 조회 실패 시 네이티브가 사용)
        // 'assets/bird_smile1.png' → 'bird_smile1', '기본이미지' → 'default_pet'
        String resourceName = evolutionImagePath
            .replaceFirst('assets/', '')
            .replaceFirst('.png', '');
        if (resourceName == '기본이미지') {
          resourceName = 'default_pet';
        }
        await HomeWidget.saveWidgetData<String>(_keyEvolutionImage, resourceName);
        await HomeWidget.saveWidgetData<String>(
          _keyEvolutionType, pet.evolutionType?.name ?? '',
        );
      } else {
        await HomeWidget.saveWidgetData<String>(_keyPixelKey, '');
        await HomeWidget.saveWidgetData<String>(_keyEvolutionImage, '');
        await HomeWidget.saveWidgetData<String>(_keyEvolutionType, '');
      }

      // 펫의 기분 상태 저장 (hunger, happiness, stamina 기반으로 계산)
      final mood = pet.mood.name; // PetMood enum의 name (happy, sleepy, hungry, bored, normal 등)
      await HomeWidget.saveWidgetData<String>(_keyMood, mood);
      
      // 펫의 이름 저장
      await HomeWidget.saveWidgetData<String>(_keyName, pet.name);
      await HomeWidget.saveWidgetData<String>(_keySyncTraceId, syncTraceId);
      
      // 펫의 기분 상태 한국어 텍스트 저장
      final moodText = _getMoodText(pet.mood);
      await HomeWidget.saveWidgetData<String>(_keyMoodText, moodText);
      
      // 디버깅: 위젯 업데이트 시 저장되는 값 확인
      if (kDebugMode) {
        debugPrint(
          'WidgetService: syncTraceId=$syncTraceId, '
          'level=${pet.level}, mood=${pet.mood.name}, moodText=$moodText, imageType=$imageType, '
          'hunger=${pet.hunger}, happiness=${pet.happiness}, stamina=${pet.stamina}',
        );
      }
      
      // 현재 시간 기반으로 이미지 인덱스 계산 (애니메이션 효과)
      // 이미지 타입에 따라 다른 개수 사용
      // feed: 4장, 나머지: 3장
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final imageCount = imageType == 'feed' ? 4 : 3;
      final cycleDuration = imageCount * 800; // 이미지 개수 * 800ms
      final imageIndex = ((currentTime % cycleDuration) / 800).toInt() % imageCount;
      await HomeWidget.saveWidgetData<String>(_keyImageIndex, imageIndex.toString());
      
      // 위젯 업데이트 요청
      // Android: PetWidgetProvider 클래스 이름 사용
      // iOS: 위젯 Extension 이름 사용
        // 중요: 위젯이 즉시 업데이트되도록 보장
        try {
          await HomeWidget.updateWidget(
            name: 'PetWidgetProvider',
            androidName: 'PetWidgetProvider',
            qualifiedAndroidName: 'com.han.godsaengmon.PetWidgetProvider',
            iOSName: 'PetWidget',
          );
          if (kDebugMode) {
            debugPrint('WidgetService: syncTraceId=$syncTraceId, widget update requested successfully');
          }
        } catch (e) {
          // 위젯 업데이트 실패 시 로그 출력
          if (kDebugMode) {
            debugPrint('WidgetService: syncTraceId=$syncTraceId, failed to request widget update: $e');
          }
          // 실패해도 계속 진행 (위젯이 없을 수 있음)
        }
      } catch (e) {
        // 위젯 업데이트 실패는 무시 (앱 동작에 영향 없음)
        // 위젯이 설치되지 않았거나 권한이 없는 경우 발생할 수 있음
      }
    }
    
    /// 펫 상태를 한국어 텍스트로 변환
    /// 
  /// [mood] 펫의 기분 상태
  /// 
  /// 반환: 한국어 상태 텍스트
  String _getMoodText(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return AppStrings.moodHappy;
      case PetMood.normal:
        return AppStrings.moodNormal;
      case PetMood.hungry:
        return AppStrings.moodHungry;
      case PetMood.sleepy:
        return AppStrings.moodSleepy;
      case PetMood.tired:
        return AppStrings.moodTired;
      case PetMood.sad:
        return AppStrings.moodSad;
      case PetMood.dead:
        return AppStrings.moodDead;
    }
  }
  
  /// 홈 화면에 위젯 추가(핀) 요청 — 온보딩 위젯 유도 단계에서 사용
  ///
  /// Android 8.0+ 이며 런처가 지원할 때만 시스템 추가 다이얼로그가 뜬다.
  /// 반환: 요청을 띄웠으면 true, 미지원/실패면 false (호출부가 안내 문구 표시)
  Future<bool> requestPinWidget() async {
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported();
      if (supported != true) return false;
      await HomeWidget.requestPinWidget(
        name: 'PetWidgetProvider',
        androidName: 'PetWidgetProvider',
        qualifiedAndroidName: 'com.han.godsaengmon.PetWidgetProvider',
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WidgetService.requestPinWidget failed: $e');
      }
      return false;
    }
  }

  /// 위젯 초기화
  ///
  /// 앱 시작 시 위젯을 초기화하고 권한을 요청
  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.pocketfriend.widget');
    } catch (e) {
      // iOS에서만 필요하며, Android에서는 무시됨
    }
  }
}
