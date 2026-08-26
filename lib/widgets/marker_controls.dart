import 'package:flutter/material.dart';
import '../services/loop_engine.dart';

class MarkerControls extends StatefulWidget {
  final LoopEngine engine;

  const MarkerControls({super.key, required this.engine});

  @override
  State<MarkerControls> createState() => _MarkerControlsState();
}

class _MarkerControlsState extends State<MarkerControls> {
  late TextEditingController _controllerA;
  late TextEditingController _controllerB;
  late FocusNode _focusNodeA;
  late FocusNode _focusNodeB;

  @override
  void initState() {
    super.initState();
    _controllerA = TextEditingController(
      text: widget.engine.startMarkerMs != null
          ? LoopEngine.formatTime(widget.engine.startMarkerMs!)
          : '',
    );
    _controllerB = TextEditingController(
      text: widget.engine.endMarkerMs != null
          ? LoopEngine.formatTime(widget.engine.endMarkerMs!)
          : '',
    );
    _focusNodeA = FocusNode();
    _focusNodeB = FocusNode();

    _focusNodeA.addListener(_onFocusAChanged);
    _focusNodeB.addListener(_onFocusBChanged);
  }

  void _onFocusAChanged() {
    if (!_focusNodeA.hasFocus) {
      // Re-format on blur if valid
      if (widget.engine.startMarkerMs != null) {
        _controllerA.text = LoopEngine.formatTime(widget.engine.startMarkerMs!);
      }
    }
  }

  void _onFocusBChanged() {
    if (!_focusNodeB.hasFocus) {
      // Re-format on blur if valid
      if (widget.engine.endMarkerMs != null) {
        _controllerB.text = LoopEngine.formatTime(widget.engine.endMarkerMs!);
      }
    }
  }

  @override
  void didUpdateWidget(covariant MarkerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only update controller text if user is NOT actively typing inside the text field
    if (!_focusNodeA.hasFocus) {
      if (widget.engine.startMarkerMs != null) {
        final formattedA = LoopEngine.formatTime(widget.engine.startMarkerMs!);
        if (_controllerA.text != formattedA) {
          _controllerA.text = formattedA;
        }
      } else {
        if (_controllerA.text.isNotEmpty) {
          _controllerA.text = '';
        }
      }
    }

    if (!_focusNodeB.hasFocus) {
      if (widget.engine.endMarkerMs != null) {
        final formattedB = LoopEngine.formatTime(widget.engine.endMarkerMs!);
        if (_controllerB.text != formattedB) {
          _controllerB.text = formattedB;
        }
      } else {
        if (_controllerB.text.isNotEmpty) {
          _controllerB.text = '';
        }
      }
    }
  }

  @override
  void dispose() {
    _focusNodeA.removeListener(_onFocusAChanged);
    _focusNodeB.removeListener(_onFocusBChanged);
    _focusNodeA.dispose();
    _focusNodeB.dispose();
    _controllerA.dispose();
    _controllerB.dispose();
    super.dispose();
  }

  int? _parseTimeToMs(String text) {
    final cleaned = text.trim().replaceAll(' ', '');
    if (cleaned.isEmpty) return null;

    if (cleaned.contains(':')) {
      final parts = cleaned.split(':');
      if (parts.length == 2) {
        final mins = double.tryParse(parts[0]);
        final secs = double.tryParse(parts[1]);
        if (mins != null && secs != null) {
          return ((mins * 60 + secs) * 1000).round();
        }
      }
    }

    if (cleaned.contains('.')) {
      final dotParts = cleaned.split('.');
      if (dotParts.length == 3) {
        final mins = double.tryParse(dotParts[0]);
        final secs = double.tryParse(dotParts[1]);
        final tenths = double.tryParse('0.${dotParts[2]}');
        if (mins != null && secs != null && tenths != null) {
          return ((mins * 60 + secs + tenths) * 1000).round();
        }
      } else if (dotParts.length == 2) {
        final part0 = double.tryParse(dotParts[0]);
        final part1 = double.tryParse(dotParts[1]);
        if (dotParts[1].length == 2 && part1 != null && part1 < 60 && part0 != null && part0 < 60) {
          return ((part0 * 60 + part1) * 1000).round();
        } else {
          final totalSec = double.tryParse(cleaned);
          if (totalSec != null) return (totalSec * 1000).round();
        }
      }
    }

    final secs = double.tryParse(cleaned);
    if (secs != null) {
      return (secs * 1000).round();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasMarkers = widget.engine.startMarkerMs != null || widget.engine.endMarkerMs != null;

    return Column(
      children: [
        Row(
          children: [
            // Point A Station
            Expanded(
              child: _buildMarkerCard(
                title: 'Point A',
                color: const Color(0xFF00E676),
                controller: _controllerA,
                focusNode: _focusNodeA,
                hintText: '00:00.0',
                onChanged: (val) {
                  if (val.trim().isEmpty) {
                    widget.engine.setPointA(null);
                  } else {
                    final ms = _parseTimeToMs(val);
                    if (ms != null) widget.engine.setPointA(ms);
                  }
                },
                onSubmitted: (val) {
                  _focusNodeA.unfocus();
                  if (val.trim().isEmpty) {
                    widget.engine.setPointA(null);
                  } else {
                    final ms = _parseTimeToMs(val);
                    if (ms != null) {
                      widget.engine.setPointA(ms);
                      _controllerA.text = LoopEngine.formatTime(ms);
                    }
                  }
                },
                onSetCurrent: () {
                  widget.engine.setPointAToCurrent();
                  if (widget.engine.startMarkerMs != null) {
                    _controllerA.text = LoopEngine.formatTime(widget.engine.startMarkerMs!);
                  }
                },
                onJump: widget.engine.startMarkerMs != null ? () => widget.engine.jumpToA() : null,
                onNudge: (ms) {
                  widget.engine.nudgeA(ms);
                  if (widget.engine.startMarkerMs != null) {
                    _controllerA.text = LoopEngine.formatTime(widget.engine.startMarkerMs!);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            // Point B Station
            Expanded(
              child: _buildMarkerCard(
                title: 'Point B',
                color: const Color(0xFFFF5252),
                controller: _controllerB,
                focusNode: _focusNodeB,
                hintText: '00:00.0',
                onChanged: (val) {
                  if (val.trim().isEmpty) {
                    widget.engine.setPointB(null);
                  } else {
                    final ms = _parseTimeToMs(val);
                    if (ms != null) widget.engine.setPointB(ms);
                  }
                },
                onSubmitted: (val) {
                  _focusNodeB.unfocus();
                  if (val.trim().isEmpty) {
                    widget.engine.setPointB(null);
                  } else {
                    final ms = _parseTimeToMs(val);
                    if (ms != null) {
                      widget.engine.setPointB(ms);
                      _controllerB.text = LoopEngine.formatTime(ms);
                    }
                  }
                },
                onSetCurrent: () {
                  widget.engine.setPointBToCurrent();
                  if (widget.engine.endMarkerMs != null) {
                    _controllerB.text = LoopEngine.formatTime(widget.engine.endMarkerMs!);
                  }
                },
                onJump: widget.engine.endMarkerMs != null ? () => widget.engine.jumpToB() : null,
                onNudge: (ms) {
                  widget.engine.nudgeB(ms);
                  if (widget.engine.endMarkerMs != null) {
                    _controllerB.text = LoopEngine.formatTime(widget.engine.endMarkerMs!);
                  }
                },
              ),
            ),
          ],
        ),

        if (hasMarkers) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () {
                _focusNodeA.unfocus();
                _focusNodeB.unfocus();
                widget.engine.resetMarkers();
                _controllerA.text = '';
                _controllerB.text = '';
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              icon: const Icon(Icons.close_rounded, size: 15),
              label: const Text(
                'Clear A-B Markers',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMarkerCard({
    required String title,
    required Color color,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSubmitted,
    required VoidCallback onSetCurrent,
    required VoidCallback? onJump,
    required Function(int ms) onNudge,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14151E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF232532)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Title & Jump Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (onJump != null)
                InkWell(
                  onTap: onJump,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Text(
                      'Jump ➔',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Digital Time Display Box (Can be cleared freely)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0D13),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF232532)),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: color,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 7),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(height: 8),

          // Set Current Button
          ElevatedButton.icon(
            onPressed: onSetCurrent,
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.14),
              foregroundColor: color,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: color.withOpacity(0.35)),
              ),
            ),
            icon: const Icon(Icons.touch_app_rounded, size: 15),
            label: const Text(
              'Set Current',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),

          // 4-Segment Micro-Nudge Row (Equally Spaced)
          Row(
            children: [
              _buildNudgeBtn('-1s', () => onNudge(-1000)),
              const SizedBox(width: 4),
              _buildNudgeBtn('-0.1s', () => onNudge(-100)),
              const SizedBox(width: 4),
              _buildNudgeBtn('+0.1s', () => onNudge(100)),
              const SizedBox(width: 4),
              _buildNudgeBtn('+1s', () => onNudge(1000)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeBtn(String text, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1E2B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2B2E3E)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD0D0E0),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
