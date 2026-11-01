import 'package:flutter/material.dart';
import '../services/loop_engine.dart';
import '../ui_theme.dart';

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
      if (widget.engine.startMarkerMs != null) {
        _controllerA.text = LoopEngine.formatTime(widget.engine.startMarkerMs!);
      }
    }
  }

  void _onFocusBChanged() {
    if (!_focusNodeB.hasFocus) {
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
    var cleaned =
        text.trim().replaceAll(' ', '').replaceAll(RegExp(r'[\.:,\s]+$'), '');
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

    if (cleaned.isEmpty) return null;

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
        if (dotParts[1].length == 2 &&
            part1 != null &&
            part1 < 60 &&
            part0 != null &&
            part0 < 60) {
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
    final hasMarkers = widget.engine.startMarkerMs != null ||
        widget.engine.endMarkerMs != null;

    return Column(
      children: [
        Row(
          children: [
            // Point A Station
            Expanded(
              child: _buildMarkerCard(
                title: 'Point A',
                subtitle: 'loop start',
                color: SpotiTheme.pointA,
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
                    _controllerA.text =
                        LoopEngine.formatTime(widget.engine.startMarkerMs!);
                  }
                },
                onJump: widget.engine.startMarkerMs != null
                    ? () => widget.engine.jumpToA()
                    : null,
                onNudge: (ms) {
                  widget.engine.nudgeA(ms);
                  if (widget.engine.startMarkerMs != null) {
                    _controllerA.text =
                        LoopEngine.formatTime(widget.engine.startMarkerMs!);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            // Point B Station
            Expanded(
              child: _buildMarkerCard(
                title: 'Point B',
                subtitle: 'loop end',
                color: SpotiTheme.pointB,
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
                    _controllerB.text =
                        LoopEngine.formatTime(widget.engine.endMarkerMs!);
                  }
                },
                onJump: widget.engine.endMarkerMs != null
                    ? () => widget.engine.jumpToB()
                    : null,
                onNudge: (ms) {
                  widget.engine.nudgeB(ms);
                  if (widget.engine.endMarkerMs != null) {
                    _controllerB.text =
                        LoopEngine.formatTime(widget.engine.endMarkerMs!);
                  }
                },
              ),
            ),
          ],
        ),
        if (hasMarkers) ...[
          const SizedBox(height: 10),
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
                foregroundColor: SpotiTheme.faint,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.close_rounded, size: 14),
              label: const Text(
                'Clear A-B Markers',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMarkerCard({
    required String title,
    required String subtitle,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SpotiTheme.cardRadius),
        child: Stack(
          children: [
            // Top accent hairline
            Positioned(
              top: 0,
              left: 22,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: label + jump
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: SpotiTheme.faint,
                            ),
                          ),
                        ],
                      ),
                      if (onJump != null)
                        InkWell(
                          onTap: onJump,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: SpotiTheme.surface2,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: SpotiTheme.stroke),
                            ),
                            child: Text(
                              'Jump →',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: SpotiTheme.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),

                  // Digital Time Display Box
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF050608),
                      borderRadius:
                          BorderRadius.circular(SpotiTheme.insetRadius),
                      border: Border.all(color: SpotiTheme.stroke),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.text,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: color,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: const TextStyle(
                          color: SpotiTheme.faint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                    ),
                  ),
                  const SizedBox(height: 9),

                  // Set Current Button
                  ElevatedButton(
                    onPressed: onSetCurrent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.withOpacity(0.12),
                      foregroundColor: color,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SpotiTheme.insetRadius),
                        side: BorderSide(color: color.withOpacity(0.4)),
                      ),
                      overlayColor: color.withOpacity(0.1),
                    ),
                    child: const Text(
                      'Set Current',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Micro-Nudge Grid (2x2)
                  Row(
                    children: [
                      _buildNudgeBtn('−1.0s', () => onNudge(-1000)),
                      const SizedBox(width: 5),
                      _buildNudgeBtn('+1.0s', () => onNudge(1000)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _buildNudgeBtn('−0.1s', () => onNudge(-100)),
                      const SizedBox(width: 5),
                      _buildNudgeBtn('+0.1s', () => onNudge(100)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNudgeBtn(String text, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SpotiTheme.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SpotiTheme.stroke),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC4CBD8),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
