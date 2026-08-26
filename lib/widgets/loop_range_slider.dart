import 'package:flutter/material.dart';
import '../services/loop_engine.dart';

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
        children: [
          // High-frequency Progress Scrubber Bar
          ValueListenableBuilder<int>(
            valueListenable: engine.progressNotifier,
            builder: (context, liveProgress, _) {
              final progress = _isScrubbing
                  ? (_scrubFraction * maxDuration).toInt()
                  : liveProgress;

              final progressFraction = (progress / maxDuration).clamp(0.0, 1.0);
              final startFraction = startA != null ? (startA / maxDuration).clamp(0.0, 1.0) : 0.0;
              final endFraction = endB != null ? (endB / maxDuration).clamp(0.0, 1.0) : 1.0;

              return Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          final tapFraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                          final targetMs = (tapFraction * maxDuration).toInt();
                          engine.seek(targetMs);
                        },
                        onHorizontalDragStart: (details) {
                          if (_isDraggingA || _isDraggingB) return;
                          setState(() {
                            _isScrubbing = true;
                            _scrubFraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                          });
                        },
                        onHorizontalDragUpdate: (details) {
                          if (_isDraggingA || _isDraggingB) return;
                          setState(() {
                            _scrubFraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                          });
                        },
                        onHorizontalDragEnd: (details) {
                          if (_isDraggingA || _isDraggingB) return;
                          final targetMs = (_scrubFraction * maxDuration).toInt();
                          setState(() {
                            _isScrubbing = false;
                          });
                          engine.seek(targetMs);
                        },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Base Track Background
                              Center(
                                child: Container(
                                  height: 6,
                                  width: width,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF232532),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),

                              // Progress Fill
                              Positioned(
                                left: 0,
                                top: 19,
                                child: Container(
                                  height: 6,
                                  width: (progressFraction * width).clamp(0.0, width),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1DB954), Color(0xFF00E676)],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),

                              // Loop Region Highlight Zone
                              if (startA != null && endB != null && endB > startA)
                                Positioned(
                                  left: startFraction * width,
                                  top: 17,
                                  child: Container(
                                    height: 10,
                                    width: ((endFraction - startFraction) * width).clamp(2.0, width),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1DB954).withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFF1DB954).withOpacity(0.6),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),

                              // Marker A Pin (Neon Emerald)
                              if (startA != null)
                                Positioned(
                                  left: (startFraction * width - 9).clamp(0.0, width - 18),
                                  top: 10,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragStart: (_) => _isDraggingA = true,
                                    onHorizontalDragUpdate: (details) {
                                      final newFraction = ((startFraction * width + details.delta.dx) / width).clamp(0.0, endFraction - 0.01);
                                      engine.setPointA((newFraction * maxDuration).toInt());
                                    },
                                    onHorizontalDragEnd: (_) => _isDraggingA = false,
                                    child: _buildMarkerPill('A', const Color(0xFF00E676)),
                                  ),
                                ),

                              // Marker B Pin (Coral Red)
                              if (endB != null)
                                Positioned(
                                  left: (endFraction * width - 9).clamp(0.0, width - 18),
                                  top: 10,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragStart: (_) => _isDraggingB = true,
                                    onHorizontalDragUpdate: (details) {
                                      final newFraction = ((endFraction * width + details.delta.dx) / width).clamp(startFraction + 0.01, 1.0);
                                      engine.setPointB((newFraction * maxDuration).toInt());
                                    },
                                    onHorizontalDragEnd: (_) => _isDraggingB = false,
                                    child: _buildMarkerPill('B', const Color(0xFFFF5252)),
                                  ),
                                ),

                              // Current Playhead Needle (Glowing White Dot)
                              Positioned(
                                left: (progressFraction * width - 7).clamp(0.0, width - 14),
                                top: 15,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.8),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.6),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
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

                  const SizedBox(height: 6),

                  // Clean 3-Column Time Labels Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Current Time
                      Text(
                        LoopEngine.formatTime(progress),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),

                      // Loop Duration Badge (Center)
                      if (startA != null && endB != null && endB > startA)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
                          ),
                          child: Text(
                            'Loop: ${LoopEngine.formatTime(endB - startA)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00E676),
                              fontFamily: 'monospace',
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      // Total Duration
                      Text(
                        LoopEngine.formatTime(duration),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF888894),
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

          // Quick Micro-Seek Jump Buttons (Evenly Spread)
          Row(
            children: [
              _buildQuickSeekBtn('-5s', () => engine.seek(engine.liveProgressMs - 5000)),
              const SizedBox(width: 8),
              _buildQuickSeekBtn('-1s', () => engine.seek(engine.liveProgressMs - 1000)),
              const SizedBox(width: 8),
              _buildQuickSeekBtn('+1s', () => engine.seek(engine.liveProgressMs + 1000)),
              const SizedBox(width: 8),
              _buildQuickSeekBtn('+5s', () => engine.seek(engine.liveProgressMs + 5000)),
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
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1B1D28),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2B2E3E)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC0C0D0),
                fontFamily: 'monospace',
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
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Colors.black45,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
