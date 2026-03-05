import 'package:home_widget/home_widget.dart';
import '../../domain/entities/pet.dart';

/// 홈 화면 위젯 서비스
/// 펫 데이터를 홈 화면 위젯에 업데이트하는 서비스
/// 
/// Android와 iOS 홈 화면 위젯에 펫 정보를 표시하기 위해 사용
class WidgetService {
  /// 위젯 업데이트 키 상수
  static const String _keyHunger = 'hunger';
  static const String _keyHappiness = 'happiness';
  static const String _keyStamina = 'stamina';
  static const String _keyLevel = 'level';
  static const String _keyExp = 'exp';
  static const String _keyEvolutionStage = 'evolutionStage';
  static const String _keyLastUpdated = 'lastUpdated';
  
  /// 펫 데이터를 위젯에 업데이트
  /// 
  /// [pet] 업데이트할 펫 엔티티
  /// 
  /// 펫의 상태 정보를 홈 화면 위젯에 전달하여 표시
  Future<void> updatePetWidget(Pet pet) async {
    try {
      await HomeWidget.saveWidgetData<String>(_keyHunger, pet.hunger.toString());
      await HomeWidget.saveWidgetData<String>(_keyHappiness, pet.happiness.toString());
      await HomeWidget.saveWidgetData<String>(_keyStamina, pet.stamina.toString());
      await HomeWidget.saveWidgetData<String>(_keyLevel, pet.level.toString());
      await HomeWidget.saveWidgetData<String>(_keyExp, pet.exp.toString());
      await HomeWidget.saveWidgetData<String>(_keyEvolutionStage, pet.evolutionStage.toString());
      await HomeWidget.saveWidgetData<String>(_keyLastUpdated, pet.lastUpdated.toString());
      
      // 위젯 업데이트 요청
      // Android: PetWidgetProvider 클래스 이름 사용
      // iOS: 위젯 Extension 이름 사용
      await HomeWidget.updateWidget(
        name: 'PetWidgetProvider',
        iOSName: 'PetWidget',
      );
    } catch (e) {
      // 위젯 업데이트 실패는 무시 (앱 동작에 영향 없음)
      // 위젯이 설치되지 않았거나 권한이 없는 경우 발생할 수 있음
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
