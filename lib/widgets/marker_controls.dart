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
  }

  @override
  void didUpdateWidget(covariant MarkerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.engine.startMarkerMs != null) {
      final formattedA = LoopEngine.formatTime(widget.engine.startMarkerMs!);
      if (_controllerA.text != formattedA) {
        _controllerA.text = formattedA;
      }
    } else {
      _controllerA.text = '';
    }

    if (widget.engine.endMarkerMs != null) {
      final formattedB = LoopEngine.formatTime(widget.engine.endMarkerMs!);
      if (_controllerB.text != formattedB) {
        _controllerB.text = formattedB;
      }
    } else {
      _controllerB.text = '';
    }
  }

  @override
  void dispose() {
    _controllerA.dispose();
    _controllerB.dispose();
    super.dispose();
  }

  int? _parseTimeToMs(String text) {
    final cleaned = text.trim().replaceAll(' ', '');
    if (cleaned.isEmpty) return null;

    // 1. Colon format: 1:14 or 1:14.5
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

    // 2. Dot notation: 1.14.5 or 1.14 or 74.5
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

    // 3. Plain seconds: 45
    final secs = double.tryParse(cleaned);
    if (secs != null) {
      return (secs * 1000).round();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Point A Card
            Expanded(
              child: _buildMarkerCard(
                title: 'Point A (Start)',
                icon: Icons.flag_rounded,
                color: const Color(0xFF00E676),
                controller: _controllerA,
                hintText: '00:00.0 or sec',
                onSubmitted: (val) {
                  final ms = _parseTimeToMs(val);
                  if (ms != null) widget.engine.setPointA(ms);
                },
                onSetCurrent: () => widget.engine.setPointAToCurrent(),
                onJump: widget.engine.startMarkerMs != null ? () => widget.engine.jumpToA() : null,
                onNudge: (ms) => widget.engine.nudgeA(ms),
              ),
            ),
            const SizedBox(width: 12),
            // Point B Card
            Expanded(
              child: _buildMarkerCard(
                title: 'Point B (End)',
                icon: Icons.flag_circle_rounded,
                color: const Color(0xFFFF5252),
                controller: _controllerB,
                hintText: '00:00.0 or sec',
                onSubmitted: (val) {
                  final ms = _parseTimeToMs(val);
                  if (ms != null) widget.engine.setPointB(ms);
                },
                onSetCurrent: () => widget.engine.setPointBToCurrent(),
                onJump: widget.engine.endMarkerMs != null ? () => widget.engine.jumpToB() : null,
                onNudge: (ms) => widget.engine.nudgeB(ms),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Quick Reset Row
        if (widget.engine.startMarkerMs != null || widget.engine.endMarkerMs != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => widget.engine.resetMarkers(),
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear A-B Markers', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }

  Widget _buildMarkerCard({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onSubmitted,
    required VoidCallback onSetCurrent,
    required VoidCallback? onJump,
    required Function(int ms) onNudge,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              if (onJump != null)
                InkWell(
                  onTap: onJump,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text('Jump ➔', style: TextStyle(fontSize: 11, color: Colors.white60)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Editable Time Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF11131A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: color,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(height: 8),

          // Set Current Button
          ElevatedButton.icon(
            onPressed: onSetCurrent,
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.18),
              foregroundColor: color,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: color.withOpacity(0.35)),
              ),
            ),
            icon: const Icon(Icons.touch_app_rounded, size: 15),
            label: const Text('Set Current', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 8),

          // Sub-second Nudges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNudgeBtn('-1s', () => onNudge(-1000)),
              _buildNudgeBtn('-0.1s', () => onNudge(-100)),
              _buildNudgeBtn('+0.1s', () => onNudge(100)),
              _buildNudgeBtn('+1s', () => onNudge(1000)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeBtn(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF25293A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
      ),
    );
  }
}
