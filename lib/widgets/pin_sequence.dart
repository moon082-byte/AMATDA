import 'package:flutter/material.dart';
import 'pin_pad.dart';

/// PIN 입력 한 단계
class PinStepSpec {
  final String title;
  final String? subtitle;
  final int length;

  /// 앞 단계 값과 같아야 하는 확인 단계면 그 단계 번호
  final int? confirms;

  const PinStepSpec(this.title, {this.subtitle, this.length = 4, this.confirms});
}

/// 여러 단계(현재 PIN → 새 PIN → 한 번 더)를 차례로 입력받아 [onFinish]에 넘긴다.
/// [onFinish]가 안내 문구를 돌려주면(실패) 그 문구를 보여주고 처음 단계부터 다시 받는다.
class PinSequence extends StatefulWidget {
  final List<PinStepSpec> steps;
  final Future<String?> Function(List<String> values) onFinish;

  /// 처음 화면에 보여줄 안내 (예: 잠금 시간)
  final String? error;
  final bool enabled;

  const PinSequence({
    super.key,
    required this.steps,
    required this.onFinish,
    this.error,
    this.enabled = true,
  });

  @override
  State<PinSequence> createState() => _PinSequenceState();
}

class _PinSequenceState extends State<PinSequence> {
  final _values = <String>[];
  String? _error;
  bool _busy = false;

  Future<void> _completed(String value) async {
    final step = widget.steps[_values.length];
    final confirms = step.confirms;
    if (confirms != null && _values[confirms] != value) {
      setState(() {
        _values.removeRange(confirms, _values.length);
        _error = 'PIN이 서로 달라요. 다시 입력해 주세요';
      });
      return;
    }
    _values.add(value);
    if (_values.length < widget.steps.length) {
      setState(() => _error = null);
      return;
    }
    setState(() => _busy = true);
    final error = await widget.onFinish(List.of(_values));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      _values.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_values.length.clamp(0, widget.steps.length - 1)];
    return PinPad(
      title: step.title,
      subtitle: step.subtitle,
      length: step.length,
      error: _error ?? widget.error,
      enabled: widget.enabled && !_busy,
      onCompleted: _completed,
    );
  }
}
