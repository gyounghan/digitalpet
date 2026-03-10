import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../../domain/entities/pet.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../core/constants/app_strings.dart';

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
  static const String _keyImageType = 'imageType'; // 펫 이미지 타입 (sleeping/hungry/normal)
  static const String _keyImageIndex = 'imageIndex'; // 현재 표시할 이미지 인덱스 (0~3)
  static const String _keyMood = 'mood'; // 펫의 기분 상태 (happy, sleepy, hungry, bored, normal 등)
  static const String _keyMoodText = 'moodText'; // 펫의 기분 상태 한국어 텍스트
  static const String _keyName = 'name'; // 펫의 이름
  
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
      await HomeWidget.saveWidgetData<String>(_keyHunger, pet.hunger.toString());
      await HomeWidget.saveWidgetData<String>(_keyHappiness, pet.happiness.toString());
      await HomeWidget.saveWidgetData<String>(_keyStamina, pet.stamina.toString());
      await HomeWidget.saveWidgetData<String>(_keyLevel, pet.level.toString());
      await HomeWidget.saveWidgetData<String>(_keyExp, pet.exp.toString());
      await HomeWidget.saveWidgetData<String>(_keyEvolutionStage, pet.evolutionStage.toString());
      await HomeWidget.saveWidgetData<String>(_keyLastUpdated, pet.lastUpdated.toString());
      await HomeWidget.saveWidgetData<String>(_keyImageType, imageType);
      
      // 펫의 기분 상태 저장 (hunger, happiness, stamina 기반으로 계산)
      final mood = pet.mood.name; // PetMood enum의 name (happy, sleepy, hungry, bored, normal 등)
      await HomeWidget.saveWidgetData<String>(_keyMood, mood);
      
      // 펫의 이름 저장
      await HomeWidget.saveWidgetData<String>(_keyName, pet.name);
      
      // 펫의 기분 상태 한국어 텍스트 저장
      final moodText = _getMoodText(pet.mood);
      await HomeWidget.saveWidgetData<String>(_keyMoodText, moodText);
      
      // 디버깅: 위젯 업데이트 시 저장되는 값 확인
      if (kDebugMode) {
        debugPrint('WidgetService: Updating widget - level: ${pet.level}, moodText: $moodText, mood: ${pet.mood.name}, hunger: ${pet.hunger}, happiness: ${pet.happiness}, stamina: ${pet.stamina}');
      }
      
      // 현재 시간 기반으로 이미지 인덱스 계산 (애니메이션 효과)
      // 이미지 타입에 따라 다른 개수 사용
      // sleeping: 3장, hungry: 4장
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final imageCount = imageType == 'hungry' ? 4 : 3;
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
          iOSName: 'PetWidget',
        );
        if (kDebugMode) {
          debugPrint('WidgetService: Widget update requested successfully');
        }
      } catch (e) {
        // 위젯 업데이트 실패 시 로그 출력
        if (kDebugMode) {
          debugPrint('WidgetService: Failed to request widget update: $e');
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
      case PetMood.sleepy:
        return AppStrings.moodSleepy;
      case PetMood.hungry:
        return AppStrings.moodHungry;
      case PetMood.bored:
        return AppStrings.moodBored;
      case PetMood.normal:
        return AppStrings.moodNormal;
      case PetMood.energetic:
        return AppStrings.moodEnergetic;
      case PetMood.tired:
        return AppStrings.moodTired;
      case PetMood.full:
        return AppStrings.moodFull;
      case PetMood.anxious:
        return AppStrings.moodAnxious;
      case PetMood.satisfied:
        return AppStrings.moodSatisfied;
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
