/// 소셜 로그인 앱 키 설정
///
/// 네이티브 앱 키는 APK에 원래 포함되는 공개 값이므로 상수로 둔다.
/// 다른 키로 빌드하려면 --dart-define=KAKAO_NATIVE_APP_KEY=... 로 덮어쓴다.
/// 콘솔 등록 정보: 패키지명 com.han.godsaengmon (developers.kakao.com)
class AuthConfig {
  AuthConfig._();

  static const String kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '69149dbdee09fd8c86c977bfea06f620',
  );
}
