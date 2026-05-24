import 'package:flutter/foundation.dart';
import '../../domain/entities/pet.dart';
import '../../domain/repositories/pet_remote_repository.dart';
import '../datasources/pet_remote_datasource.dart';
import '../datasources/device_id_datasource.dart';
import '../models/pet_model.dart';

/// PetRemoteRepository 구현체
///
/// HTTP를 통해 NestJS 서버와 통신하여 펫 데이터를 동기화.
/// 모든 호출에서 서버 unreachable은 silent fail 처리.
class PetRemoteRepositoryImpl implements PetRemoteRepository {
  final PetRemoteDatasource remoteDatasource;
  final DeviceIdDatasource deviceIdDatasource;

  PetRemoteRepositoryImpl({
    required this.remoteDatasource,
    required this.deviceIdDatasource,
  });

  @override
  Future<Pet?> getPet(String petId) async {
    try {
      final deviceId = await deviceIdDatasource.getOrCreateDeviceId();
      final json = await remoteDatasource.getPet(deviceId);
      if (json == null) return null;
      return PetModel.fromJson(json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetRemoteRepositoryImpl.getPet failed: $e');
      }
      return null;
    }
  }

  @override
  Future<void> savePet(Pet pet) async {
    try {
      final deviceId = await deviceIdDatasource.getOrCreateDeviceId();
      final json = PetModel.fromEntity(pet).toJson();
      await remoteDatasource.syncPet(deviceId, json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetRemoteRepositoryImpl.savePet failed: $e');
      }
    }
  }

  @override
  Future<Pet> syncPet(String petId) async {
    // SyncPetUseCase가 이 로직을 담당하므로 여기서는 단순 조회
    final pet = await getPet(petId);
    if (pet != null) return pet;
    throw Exception('서버에 펫 데이터 없음');
  }

  /// 이전 코드 생성
  Future<String?> generateTransferCode() async {
    final deviceId = await deviceIdDatasource.getOrCreateDeviceId();
    return remoteDatasource.generateTransferCode(deviceId);
  }

  /// 이전 코드로 펫 복원
  Future<Pet?> transferFromCode(String transferCode) async {
    try {
      final deviceId = await deviceIdDatasource.getOrCreateDeviceId();
      final json = await remoteDatasource.transferPet(deviceId, transferCode);
      if (json == null) return null;
      return PetModel.fromJson(json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetRemoteRepositoryImpl.transferFromCode failed: $e');
      }
      return null;
    }
  }
}
