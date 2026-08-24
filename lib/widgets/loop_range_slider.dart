import 'package:flutter/material.dart';
import '../services/loop_engine.dart';

class LoopRangeSlider extends StatelessWidget {
  final LoopEngine engine;

  const LoopRangeSlider({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final duration = engine.durationMs;
    final progress = engine.liveProgressMs;
    final startA = engine.startMarkerMs;
    final endB = engine.endMarkerMs;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                child: Container(
                  height: 48,
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
                      // Loop Active Zone (Green Highlight)
                      if (startA != null && endB != null)
                        Positioned(
                          left: startFraction * width,
                          top: 21,
                          child: Container(
                            height: 6,
                            width: ((endFraction - startFraction) * width).clamp(2.0, width),
                            decoration: BoxDecoration(
                              color: engine.isLoopActive
                                  ? const Color(0xFF1DB954).withOpacity(0.8)
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
                      // Marker A Pin (Green)
                      if (startA != null)
                        Positioned(
                          left: (startFraction * width) - 8,
                          top: 8,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              final newFraction = ((startFraction * width + details.delta.dx) / width).clamp(0.0, endFraction - 0.01);
                              engine.setPointA((newFraction * maxDuration).toInt());
                            },
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
                          left: (endFraction * width) - 8,
                          top: 8,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              final newFraction = ((endFraction * width + details.delta.dx) / width).clamp(startFraction + 0.01, 1.0);
                              engine.setPointB((newFraction * maxDuration).toInt());
                            },
                            child: _buildPin(
                              label: 'B',
                              color: const Color(0xFFFF5252),
                              tooltip: 'Point B: ${LoopEngine.formatTime(endB)}',
                            ),
                          ),
                        ),
                      // Current Playhead Cursor
                      Positioned(
                        left: (progressFraction * width) - 6,
                        top: 18,
                        child: IgnorePointer(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
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
          const SizedBox(height: 8),
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
                          fontWeight: FontWeight.w600,
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              Text(
                LoopEngine.formatTime(duration),
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPin({required String label, required Color color, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 16,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
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
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}
