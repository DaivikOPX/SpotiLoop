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
  String? _activeDragMarker; // 'A', 'B', or null

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final duration = engine.durationMs;
    final progress = _isScrubbing
        ? (_scrubFraction * (duration > 0 ? duration : 1)).toInt()
        : engine.liveProgressMs;
    final startA = engine.startMarkerMs;
    final endB = engine.endMarkerMs;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Timeline Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final maxDuration = duration > 0 ? duration : 1;

              final progressFraction = (progress / maxDuration).clamp(0.0, 1.0);
              final startFraction = startA != null ? (startA / maxDuration).clamp(0.0, 1.0) : 0.0;
              final endFraction = endB != null ? (endB / maxDuration).clamp(0.0, 1.0) : 1.0;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final tapFraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                  final targetMs = (tapFraction * maxDuration).toInt();
                  engine.seek(targetMs);
                },
                onHorizontalDragStart: (details) {
                  setState(() {
                    _isScrubbing = true;
                    _scrubFraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _scrubFraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragEnd: (details) {
                  final targetMs = (_scrubFraction * maxDuration).toInt();
                  setState(() {
                    _isScrubbing = false;
                  });
                  engine.seek(targetMs);
                },
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Base Track (Gray)
                      Center(
                        child: Container(
                          height: 6,
                          width: width,
                          decoration: BoxDecoration(
                            color: const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),

                      // Progress Fill
                      Positioned(
                        left: 0,
                        top: 24,
                        child: Container(
                          height: 6,
                          width: (progressFraction * width).clamp(0.0, width),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),

                      // Loop Active Zone (Green Highlight)
                      if (startA != null && endB != null)
                        Positioned(
                          left: startFraction * width,
                          top: 24,
                          child: Container(
                            height: 6,
                            width: ((endFraction - startFraction) * width).clamp(2.0, width),
                            decoration: BoxDecoration(
                              color: engine.isLoopActive
                                  ? const Color(0xFF1DB954).withOpacity(0.85)
                                  : Colors.white30,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: engine.isLoopActive
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF1DB954).withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),

                      // Floating Scrub Tooltip
                      if (_isScrubbing)
                        Positioned(
                          left: (progressFraction * width) - 28,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF181818),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF1DB954)),
                            ),
                            child: Text(
                              LoopEngine.formatTime(progress),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1DB954),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),

                      // Marker A Pin (Green)
                      if (startA != null)
                        Positioned(
                          left: (startFraction * width) - 10,
                          top: 11,
                          child: GestureDetector(
                            onHorizontalDragStart: (_) => setState(() => _activeDragMarker = 'A'),
                            onHorizontalDragUpdate: (details) {
                              final newFraction = ((startFraction * width + details.delta.dx) / width).clamp(0.0, endFraction - 0.01);
                              engine.setPointA((newFraction * maxDuration).toInt());
                            },
                            onHorizontalDragEnd: (_) => setState(() => _activeDragMarker = null),
                            child: _buildPin(
                              label: 'A',
                              color: const Color(0xFF1DB954),
                              tooltip: 'Point A: ${LoopEngine.formatTime(startA)}',
                            ),
                          ),
                        ),

                      // Marker B Pin (Red / Coral)
                      if (endB != null)
                        Positioned(
                          left: (endFraction * width) - 10,
                          top: 11,
                          child: GestureDetector(
                            onHorizontalDragStart: (_) => setState(() => _activeDragMarker = 'B'),
                            onHorizontalDragUpdate: (details) {
                              final newFraction = ((endFraction * width + details.delta.dx) / width).clamp(startFraction + 0.01, 1.0);
                              engine.setPointB((newFraction * maxDuration).toInt());
                            },
                            onHorizontalDragEnd: (_) => setState(() => _activeDragMarker = null),
                            child: _buildPin(
                              label: 'B',
                              color: const Color(0xFFFF5252),
                              tooltip: 'Point B: ${LoopEngine.formatTime(endB)}',
                            ),
                          ),
                        ),

                      // Current Playhead Cursor
                      Positioned(
                        left: (progressFraction * width) - 7,
                        top: 20,
                        child: IgnorePointer(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.6),
                                  blurRadius: 4,
                                  spreadRadius: 1,
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

          // Time Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LoopEngine.formatTime(progress),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              if (startA != null || endB != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (startA != null)
                      Text(
                        'A: ${LoopEngine.formatTime(startA)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1DB954),
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    if (startA != null && endB != null)
                      const Text(' ➔ ', style: TextStyle(fontSize: 12, color: Colors.white38)),
                    if (endB != null)
                      Text(
                        'B: ${LoopEngine.formatTime(endB)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF5252),
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              Text(
                LoopEngine.formatTime(duration),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Quick Micro-Seek Jump Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuickSeekBtn('-5s', () => engine.seek(progress - 5000)),
              const SizedBox(width: 8),
              _buildQuickSeekBtn('-1s', () => engine.seek(progress - 1000)),
              const SizedBox(width: 8),
              _buildQuickSeekBtn('+1s', () => engine.seek(progress + 1000)),
              const SizedBox(width: 8),
              _buildQuickSeekBtn('+5s', () => engine.seek(progress + 5000)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSeekBtn(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildPin({required String label, required Color color, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 20,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 6,
              spreadRadius: 1,
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
      ),
    );
  }
}
