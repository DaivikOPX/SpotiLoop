import 'package:flutter/material.dart';
import '../services/loop_engine.dart';
import '../ui_theme.dart';

class LoopRangeSlider extends StatefulWidget {
  final LoopEngine engine;

  const LoopRangeSlider({super.key, required this.engine});

  @override
  State<LoopRangeSlider> createState() => _LoopRangeSliderState();
}

class _LoopRangeSliderState extends State<LoopRangeSlider> {
  bool _isScrubbing = false;
  double _scrubFraction = 0.0;
  bool _isDraggingA = false;
  bool _isDraggingB = false;

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final duration = engine.durationMs;
    final maxDuration = duration > 0 ? duration : 1;

    final startA = engine.startMarkerMs;
    final endB = engine.endMarkerMs;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: SpotiTheme.surface1,
        borderRadius: BorderRadius.circular(SpotiTheme.cardRadius),
        border: Border.all(color: SpotiTheme.stroke),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          // High-frequency Progress Scrubber Bar
          ValueListenableBuilder<int>(
            valueListenable: engine.progressNotifier,
            builder: (context, liveProgress, _) {
              final progress = _isScrubbing
                  ? (_scrubFraction * maxDuration).toInt()
                  : liveProgress;

              final progressFraction = (progress / maxDuration).clamp(0.0, 1.0);
              final startFraction =
                  startA != null ? (startA / maxDuration).clamp(0.0, 1.0) : 0.0;
              final endFraction =
                  endB != null ? (endB / maxDuration).clamp(0.0, 1.0) : 1.0;

              return Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          final tapFraction = (details.localPosition.dx / width)
                              .clamp(0.0, 1.0);
                          final targetMs = (tapFraction * maxDuration).toInt();
                          engine.seek(targetMs);
                        },
                        onHorizontalDragStart: (details) {
                          if (_isDraggingA || _isDraggingB) return;
                          setState(() {
                            _isScrubbing = true;
                            _scrubFraction = (details.localPosition.dx / width)
                                .clamp(0.0, 1.0);
                          });
                        },
                        onHorizontalDragUpdate: (details) {
                          if (_isDraggingA || _isDraggingB) return;
                          setState(() {
                            _scrubFraction = (details.localPosition.dx / width)
                                .clamp(0.0, 1.0);
                          });
                        },
                        onHorizontalDragEnd: (details) {
                          if (_isDraggingA || _isDraggingB) return;
                          final targetMs =
                              (_scrubFraction * maxDuration).toInt();
                          setState(() {
                            _isScrubbing = false;
                          });
                          engine.seek(targetMs);
                        },
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Base Track
                              Center(
                                child: Container(
                                  height: 8,
                                  width: width,
                                  decoration: BoxDecoration(
                                    color: SpotiTheme.surface3,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),

                              // Progress Fill
                              Positioned(
                                left: 0,
                                top: 19,
                                child: Container(
                                  height: 8,
                                  width: (progressFraction * width)
                                      .clamp(0.0, width),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        SpotiTheme.greenDeep,
                                        SpotiTheme.green
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),

                              // Loop Region Highlight
                              if (startA != null &&
                                  endB != null &&
                                  endB > startA)
                                Positioned(
                                  left: startFraction * width,
                                  top: 14,
                                  child: Container(
                                    height: 18,
                                    width:
                                        ((endFraction - startFraction) * width)
                                            .clamp(2.0, width),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0x0F1ED760),
                                          Color(0x241ED760)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: const Border.fromBorderSide(
                                        BorderSide(color: Color(0x2E1ED760)),
                                      ),
                                    ),
                                  ),
                                ),

                              // Marker A Pin
                              if (startA != null)
                                Positioned(
                                  left: (startFraction * width - 9)
                                      .clamp(0.0, width - 18),
                                  top: 11,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragStart: (_) =>
                                        _isDraggingA = true,
                                    onHorizontalDragUpdate: (details) {
                                      final newFraction =
                                          ((startFraction * width +
                                                      details.delta.dx) /
                                                  width)
                                              .clamp(0.0, endFraction - 0.01);
                                      engine.setPointA(
                                          (newFraction * maxDuration).toInt());
                                    },
                                    onHorizontalDragEnd: (_) =>
                                        _isDraggingA = false,
                                    child: _buildMarkerPill(
                                        'A', SpotiTheme.pointA),
                                  ),
                                ),

                              // Marker B Pin
                              if (endB != null)
                                Positioned(
                                  left: (endFraction * width - 9)
                                      .clamp(0.0, width - 18),
                                  top: 11,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragStart: (_) =>
                                        _isDraggingB = true,
                                    onHorizontalDragUpdate: (details) {
                                      final newFraction =
                                          ((endFraction * width +
                                                      details.delta.dx) /
                                                  width)
                                              .clamp(startFraction + 0.01, 1.0);
                                      engine.setPointB(
                                          (newFraction * maxDuration).toInt());
                                    },
                                    onHorizontalDragEnd: (_) =>
                                        _isDraggingB = false,
                                    child: _buildMarkerPill(
                                        'B', SpotiTheme.pointB),
                                  ),
                                ),

                              // Playhead Needle
                              Positioned(
                                left: (progressFraction * width - 6)
                                    .clamp(0.0, width - 12),
                                top: 17,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        // outer focus ring
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.18),
                                          blurRadius: 0,
                                          spreadRadius: 3,
                                        ),
                                        // drop shadow
                                        const BoxShadow(
                                          color: Colors.black54,
                                          blurRadius: 5,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Time Labels Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LoopEngine.formatTime(progress),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),

                      // Loop Duration Badge
                      if (startA != null && endB != null && endB > startA)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: SpotiTheme.greenTint,
                            borderRadius: BorderRadius.circular(999),
                            border: const Border.fromBorderSide(
                              BorderSide(color: SpotiTheme.greenStroke),
                            ),
                          ),
                          child: Text(
                            'loop ${LoopEngine.formatTime(endB - startA)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: SpotiTheme.green,
                              fontFamily: 'monospace',
                              letterSpacing: 0.4,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      Text(
                        LoopEngine.formatTime(duration),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SpotiTheme.faint,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Quick Micro-Seek Chips
          Row(
            children: [
              _buildQuickSeekBtn(
                  '−5s', () => engine.seek(engine.liveProgressMs - 5000)),
              const SizedBox(width: 7),
              _buildQuickSeekBtn(
                  '−1s', () => engine.seek(engine.liveProgressMs - 1000)),
              const SizedBox(width: 7),
              _buildQuickSeekBtn(
                  '+1s', () => engine.seek(engine.liveProgressMs + 1000)),
              const SizedBox(width: 7),
              _buildQuickSeekBtn(
                  '+5s', () => engine.seek(engine.liveProgressMs + 5000)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSeekBtn(String label, VoidCallback onPressed) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SpotiTheme.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SpotiTheme.stroke),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC4CBD8),
                fontFamily: 'monospace',
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkerPill(String label, Color color) {
    return Container(
      width: 18,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.55),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Colors.black38,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: SpotiTheme.onGreen,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
