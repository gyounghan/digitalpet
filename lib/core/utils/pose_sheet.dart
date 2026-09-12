import '../anim/pose_sheet_manifest.dart';
import '../../domain/entities/evolution_type.dart';

/// 손수 보정한 정적 포즈시트(assets/pets/{종}_{stage}.png) 경로.
///
/// 케어·배틀·도감 대표 이미지와 진화 팝업이 이 포즈시트를 그대로 표시한다.
/// 시트가 없으면 null → 걷기 프레임/도트 폴백.
/// stage 2(유아기)~4(성숙기)만 존재하며 stage 1(털뭉치)은 종 공통이라 제외.
String? poseSheetAssetFor(EvolutionType? type, int stage) {
  if (type == null || stage < 2) return null;
  final key = '${type.name}_$stage';
  if (!poseSheetKeys.contains(key)) return null;
  return 'assets/pets/$key.png';
}
