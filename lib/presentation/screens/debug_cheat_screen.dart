import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/pet.dart';
import '../../domain/entities/evolution_type.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_motion_thumb.dart';
import 'home_screen.dart';

/// [디버그 전용] 시나리오 점검용 치트 패널
///
/// 진화 등급/종/색 변이/상성/mood는 대부분 실시간 누적(Lv15≈48일, 연속접속 등)이
/// 필요해 실제로 키워서 점검하기 어렵다. 이 화면은 펫 상태를 즉석 주입해:
///  - "직접 렌더": 주입값을 그대로 렌더 → 모든 스프라이트·색·mood 조합 눈으로 확인
///  - "진화 시뮬": 주입한 레벨·누적 카운터로 진화 유스케이스를 돌려 실제 결과 확인
/// 릴리스 전 진입 버튼과 함께 삭제한다.
class DebugCheatScreen extends ConsumerStatefulWidget {
  const DebugCheatScreen({super.key});

  @override
  ConsumerState<DebugCheatScreen> createState() => _DebugCheatScreenState();
}

class _DebugCheatScreenState extends ConsumerState<DebugCheatScreen> {
  int _level = 15;
  int _stage = 3;
  EvolutionType _type = EvolutionType.turtle;
  String _grade = 'superior';
  int _feed = 0;
  int _sleep = 0;
  int _exercise = 0;
  int _login = 0;
  int _battle = 0;
  int _totalSteps = 0;
  int _hunger = 80;
  int _happiness = 80;
  int _stamina = 80;
  int _resurrect = 0;
  bool _isDead = false;

  String _lastResult = '아직 적용 안 함';

  @override
  void initState() {
    super.initState();
    // 현재 펫에서 초기값 로드
    final pet =
        ref.read(petNotifierProvider(HomeScreen.defaultPetId)).valueOrNull;
    if (pet != null) {
      _level = pet.level;
      _stage = pet.evolutionStage;
      _type = pet.evolutionType ?? EvolutionType.turtle;
      _grade = pet.evolutionGrade.isEmpty ? 'superior' : pet.evolutionGrade;
      _feed = pet.feedAchievedCount;
      _sleep = pet.sleepAchievedCount;
      _exercise = pet.exerciseAchievedCount;
      _login = pet.consecutiveLoginDays;
      _battle = pet.battleVictoryCount;
      _totalSteps = pet.totalSteps;
      _hunger = pet.hunger;
      _happiness = pet.happiness;
      _stamina = pet.stamina;
      _resurrect = pet.resurrectCount;
      _isDead = pet.isDead;
    }
  }

  Pet _buildCheatedPet(Pet base) {
    return base.copyWith(
      level: _level,
      evolutionStage: _stage,
      evolutionType: _type,
      evolutionGrade: _grade,
      feedAchievedCount: _feed,
      sleepAchievedCount: _sleep,
      exerciseAchievedCount: _exercise,
      consecutiveLoginDays: _login,
      battleVictoryCount: _battle,
      totalSteps: _totalSteps,
      hunger: _hunger,
      happiness: _happiness,
      stamina: _stamina,
      resurrectCount: _resurrect,
      isDead: _isDead,
    );
  }

  Future<void> _apply({required bool runEvolution}) async {
    final notifier =
        ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier);
    final base =
        ref.read(petNotifierProvider(HomeScreen.defaultPetId)).valueOrNull;
    if (base == null) return;

    final result =
        await notifier.debugApplyPet(_buildCheatedPet(base), runEvolution: runEvolution);
    if (!mounted) return;
    setState(() {
      // 진화 시뮬 결과를 로컬 셀렉터에도 반영 (연쇄 확인)
      _stage = result.evolutionStage;
      _type = result.evolutionType ?? _type;
      _grade = result.evolutionGrade;
      _lastResult = '단계 ${result.evolutionStage} · ${result.evolutionType?.name ?? '-'} · '
          '${result.evolutionGrade.isEmpty ? "(등급없음)" : result.evolutionGrade} · '
          'mood ${result.mood.name} · 색변이 ${result.colorVariant}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('적용됨 → $_lastResult'), duration: const Duration(seconds: 3)),
    );
  }

  void _preset({
    required EvolutionType type,
    required int stage,
    required String grade,
    int level = 15,
    int feed = 0,
    int sleep = 0,
    int exercise = 0,
    int login = 0,
  }) {
    setState(() {
      _type = type;
      _stage = stage;
      _grade = grade;
      _level = level;
      _feed = feed;
      _sleep = sleep;
      _exercise = exercise;
      _login = login;
      _battle = 0;
      _isDead = false;
      _hunger = 80;
      _happiness = 80;
      _stamina = 80;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('치트 패널 (디버그)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _previewCard(),
          const SizedBox(height: 16),
          _section('시나리오 프리셋 (탭 후 "진화 시뮬 실행")', [
            _presetChip('주작 사신수', () => _preset(
                type: EvolutionType.bird, stage: 3, grade: 'superior', exercise: 40, feed: 40)),
            _presetChip('청룡 사신수', () => _preset(
                type: EvolutionType.snake, stage: 3, grade: 'superior', sleep: 40, feed: 40)),
            _presetChip('백호 사신수', () => _preset(
                type: EvolutionType.tiger, stage: 3, grade: 'superior', exercise: 40, login: 25)),
            _presetChip('현무 사신수', () => _preset(
                type: EvolutionType.turtle, stage: 3, grade: 'superior', sleep: 40, login: 25)),
            _presetChip('일반종(조건미달)', () => _preset(
                type: EvolutionType.bird, stage: 3, grade: 'normal', exercise: 5)),
            _presetChip('단조 상향(normal→superior)', () => _preset(
                type: EvolutionType.snake, stage: 3, grade: 'normal', level: 12, sleep: 15, feed: 15)),
            _presetChip('superior 미달→3단계 유지', () => _preset(
                type: EvolutionType.bird, stage: 3, grade: 'superior', exercise: 10, feed: 40)),
          ]),
          _section('mood 프리셋 (직접 렌더)', [
            _presetChip('happy', () => _stats(85, 80, 70)),
            _presetChip('hungry', () => _stats(20, 80, 80)),
            _presetChip('tired', () => _stats(80, 80, 20)),
            _presetChip('sleepy', () => _stats(80, 80, 35)),
            _presetChip('sad', () => _stats(80, 30, 80)),
            _presetChip('normal', () => _stats(60, 60, 60)),
            _presetChip('dead', () => setState(() => _isDead = true)),
          ]),
          const Divider(height: 32),
          _stageTypeGradeSelectors(),
          const SizedBox(height: 12),
          _intSlider('레벨', _level, 1, 30, (v) => setState(() => _level = v)),
          _intSlider('급식 달성(feed)', _feed, 0, 60, (v) => setState(() => _feed = v)),
          _intSlider('수면 달성(sleep)', _sleep, 0, 60, (v) => setState(() => _sleep = v)),
          _intSlider('운동 달성(exercise)', _exercise, 0, 60, (v) => setState(() => _exercise = v)),
          _intSlider('연속접속일(login)', _login, 0, 60, (v) => setState(() => _login = v)),
          _intSlider('전투 승리', _battle, 0, 60, (v) => setState(() => _battle = v)),
          _intSlider('누적 걸음(totalSteps)', _totalSteps, 0, 500000, (v) => setState(() => _totalSteps = v), step: 10000),
          _intSlider('부활 횟수', _resurrect, 0, 5, (v) => setState(() => _resurrect = v)),
          const Divider(height: 32),
          _intSlider('포만감(hunger)', _hunger, 0, 100, (v) => setState(() => _hunger = v)),
          _intSlider('행복(happiness)', _happiness, 0, 100, (v) => setState(() => _happiness = v)),
          _intSlider('기력(stamina)', _stamina, 0, 100, (v) => setState(() => _stamina = v)),
          SwitchListTile(
            title: const Text('사망 상태(isDead)'),
            value: _isDead,
            onChanged: (v) => setState(() => _isDead = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => _apply(runEvolution: false),
                  child: const Text('직접 렌더'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _apply(runEvolution: true),
                  child: const Text('진화 시뮬 실행'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _stats(int h, int hap, int s) => setState(() {
        _hunger = h;
        _happiness = hap;
        _stamina = s;
        _isDead = false;
      });

  Widget _previewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 96,
              child: Center(
                child: PetMotionThumb(
                  type: _type,
                  stage: _stage,
                  size: 88,
                  grade: _grade,
                  variant: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('선택: 단계 $_stage · ${_type.name} · ${_grade.isEmpty ? "(등급없음)" : _grade}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('마지막 적용 결과: $_lastResult',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }

  Widget _stageTypeGradeSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('단계', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: [1, 2, 3, 4]
              .map((s) => ChoiceChip(
                    label: Text('$s단계'),
                    selected: _stage == s,
                    onSelected: (_) => setState(() => _stage = s),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        const Text('종', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: EvolutionType.values
              .map((t) => ChoiceChip(
                    label: Text(t.name),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        const Text('등급', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: ['', 'normal', 'superior', 'mythical']
              .map((g) => ChoiceChip(
                    label: Text(g.isEmpty ? '(없음)' : g),
                    selected: _grade == g,
                    onSelected: (_) => setState(() => _grade = g),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _intSlider(String label, int value, int min, int max,
      ValueChanged<int> onChanged,
      {int step = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: ((max - min) ~/ step).clamp(1, 1000),
          label: '$value',
          onChanged: (v) => onChanged((v / step).round() * step),
        ),
      ],
    );
  }
}
