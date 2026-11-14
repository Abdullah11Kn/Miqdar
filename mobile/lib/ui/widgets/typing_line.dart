import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../motion.dart';

/// One line of text that types itself, rests, erases and types the next line, in turn.
/// Home's greeting uses it: the greeting first, then a short health line.
///
/// The caret shows only while letters move, so nothing blinks while the line rests. With
/// Reduce Motion the first line simply stands still. Screen readers hear the first line once.
class TypingLine extends StatefulWidget {
  const TypingLine({
    super.key,
    required this.lines,
    this.style,
    this.typeStep = const Duration(milliseconds: 75),
    this.eraseStep = const Duration(milliseconds: 35),
    this.firstHold = const Duration(milliseconds: 3200),
    this.hold = const Duration(milliseconds: 4200),
    this.gap = const Duration(milliseconds: 350),
  });

  /// The first line is shown first and between every other line.
  final List<String> lines;
  final TextStyle? style;
  final Duration typeStep;
  final Duration eraseStep;

  /// How long the first line rests before it is erased.
  final Duration firstHold;

  /// How long every other line rests.
  final Duration hold;

  /// The pause on an empty line before the next one types.
  final Duration gap;

  @override
  State<TypingLine> createState() => _TypingLineState();
}

enum _Phase { typing, holding, erasing, gap }

class _TypingLineState extends State<TypingLine> {
  Timer? _timer;
  bool _active = false;

  /// Turns go first line, second, first, third, ... so the greeting returns between phrases.
  int _turn = 0;
  int _shown = 0;
  _Phase _phase = _Phase.typing;

  List<String> get _lines => widget.lines.where((l) => l.isNotEmpty).toList();

  int get _lineIndex {
    final count = _lines.length;
    if (count < 2) return 0;
    if (_turn.isEven) return 0;
    return 1 + ((_turn ~/ 2) % (count - 1));
  }

  Characters get _current => _lines.isEmpty ? Characters.empty : _lines[_lineIndex].characters;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldRun = TickerMode.valuesOf(context).enabled && !MiqdarMotion.reduced(context);
    if (shouldRun && !_active) {
      _active = true;
      _schedule(Duration.zero);
    } else if (!shouldRun && _active) {
      _active = false;
      _timer?.cancel();
    }
  }

  @override
  void didUpdateWidget(TypingLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.join('\n') != widget.lines.join('\n')) {
      // Language or time of day changed: start again from the greeting.
      _turn = 0;
      _shown = 0;
      _phase = _Phase.typing;
      if (_active) _schedule(Duration.zero);
    }
  }

  void _schedule(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, _step);
  }

  void _step() {
    if (!mounted || !_active) return;
    final length = _current.length;
    setState(() {
      switch (_phase) {
        case _Phase.typing:
          if (_shown < length) _shown++;
          if (_shown >= length) _phase = _Phase.holding;
        case _Phase.holding:
          _phase = _Phase.erasing;
        case _Phase.erasing:
          if (_shown > 0) _shown--;
          if (_shown == 0) _phase = _Phase.gap;
        case _Phase.gap:
          _turn++;
          _phase = _Phase.typing;
      }
    });
    if (_lines.length < 2 && _phase == _Phase.holding) return; // nothing to change to
    _schedule(switch (_phase) {
      _Phase.typing => widget.typeStep,
      _Phase.holding => _lineIndex == 0 ? widget.firstHold : widget.hold,
      _Phase.erasing => widget.eraseStep,
      _Phase.gap => widget.gap,
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final lines = _lines;
    final first = lines.isEmpty ? '' : lines.first;
    if (!_active) {
      return Text(first, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final text = _current.take(_shown).toString();
    final moving = _phase == _Phase.typing || _phase == _Phase.erasing;
    final fontSize = style.fontSize ?? 24;
    return Semantics(
      label: first,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              // A zero-width space keeps the line's height while it is empty.
              TextSpan(text: text.isEmpty ? '​' : text),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 3),
                  child: AnimatedOpacity(
                    opacity: moving ? 1 : 0,
                    duration: MiqdarMotion.quick,
                    child: Container(
                      width: 2,
                      height: fontSize * 0.95,
                      decoration: BoxDecoration(
                        color: context.mq.ink,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          style: style,
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}
