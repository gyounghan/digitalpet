import '../../domain/entities/pet.dart';
import '../../domain/repositories/pet_repository.dart';
import '../datasource/pet_local_datasource.dart';
import '../models/pet_model.dart';

/// PetRepository 인터페이스 구현
/// Domain의 추상화된 인터페이스를 실제 구현
/// 
/// PetLocalDataSource를 사용하여 Hive에 데이터 저장/조회
class PetRepositoryImpl implements PetRepository {
  final PetLocalDataSource localDataSource;
  
  PetRepositoryImpl(this.localDataSource);
  
  @override
  Future<bool> hasPet(String id) async {
    final petModel = await localDataSource.getPet(id);
    return petModel != null;
  }
  
  @override
  Future<Pet> getPet(String id) async {
    final petModel = await localDataSource.getPet(id);
    if (petModel == null) {
      throw Exception('Pet not found: $id');
    }
    return petModel.toEntity();
  }
  
  @override
  Future<void> savePet(Pet pet) async {
    final petModel = PetModel.fromEntity(pet);
    await localDataSource.savePet(petModel);
  }
  
  @override
  Future<void> updatePet(Pet pet) async {
    final petModel = PetModel.fromEntity(pet);
    await localDataSource.updatePet(petModel);
  }
  
  @override
  Future<List<Pet>> getAllPets() async {
    final petModels = await localDataSource.getAllPets();
    return petModels.map((model) => model.toEntity()).toList();
  }
}
