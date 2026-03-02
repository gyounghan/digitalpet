import 'package:hive/hive.dart';
import '../models/pet_model.dart';
import '../../core/constants/hive_constants.dart';

/// 반려동물 로컬 데이터소스
/// Hive를 사용한 로컬 저장소 접근
/// 
/// Pet 데이터의 실제 저장/조회를 담당
class PetLocalDataSource {
  Box<PetModel>? _box;
  
  /// Hive Box 초기화
  /// 
  /// 앱 시작 시 한 번 호출하여 Hive Box를 준비
  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<PetModel>(HiveConstants.petBoxName);
    }
  }
  
  /// Hive Box 초기화 확인 및 실행
  /// 
  /// Box가 초기화되지 않았으면 자동으로 초기화
  Future<void> _ensureInitialized() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }
  
  /// ID로 반려동물 조회
  /// 
  /// [id] 반려동물 고유 ID
  /// 
  /// 반환: PetModel 인스턴스 (없으면 null)
  Future<PetModel?> getPet(String id) async {
    await _ensureInitialized();
    return _box!.get(id);
  }
  
  /// 반려동물 저장
  /// 
  /// [pet] 저장할 PetModel 인스턴스
  Future<void> savePet(PetModel pet) async {
    await _ensureInitialized();
    await _box!.put(pet.id, pet);
  }
  
  /// 반려동물 업데이트
  /// 
  /// [pet] 업데이트할 PetModel 인스턴스
  /// 
  /// savePet과 동일하지만 의미적으로 업데이트임을 명시
  Future<void> updatePet(PetModel pet) async {
    await savePet(pet);
  }
  
  /// 모든 반려동물 조회
  /// 
  /// 반환: PetModel 리스트
  Future<List<PetModel>> getAllPets() async {
    await _ensureInitialized();
    return _box!.values.toList();
  }
  
  /// Hive Box 닫기
  /// 
  /// 앱 종료 시 호출하여 리소스 정리
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}
