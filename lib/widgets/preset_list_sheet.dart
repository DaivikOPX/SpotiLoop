import 'package:flutter/material.dart';
import '../models/loop_preset.dart';
import '../services/loop_engine.dart';
import '../ui_theme.dart';

class PresetListSheet extends StatefulWidget {
  final LoopEngine engine;

  const PresetListSheet({super.key, required this.engine});

  @override
  State<PresetListSheet> createState() => _PresetListSheetState();
}

class _PresetListSheetState extends State<PresetListSheet> {
  final TextEditingController _nameController = TextEditingController();
  String _sortMode = 'recency';
  List<LoopPreset> _presets = const [];

  @override
  void initState() {
    super.initState();
    _sortMode = widget.engine.presetSortMode;
    _refreshPresets();
  }

  void _refreshPresets() {
    setState(() {
      _sortMode = widget.engine.presetSortMode;
      _presets = widget.engine.presets;
    });
  }

  Widget _sortChips() {
    final modes = {
      'recency': 'Recently Saved',
      'nameAsc': 'A → Z',
      'nameDesc': 'Z → A',
      'trackAsc': 'Track Name',
    };
    final sortedModes = modes.entries.toList()
      ..sort((a, b) => a.key == _sortMode
          ? -1
          : a.key == _sortMode
              ? 1
              : 0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (sortedModes.isNotEmpty)
            ...sortedModes.map((m) {
              final isActive = m.key == _sortMode;
              final label = m.key == _sortMode ? 'Custom Order' : m.value;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  selected: isActive,
                  onSelected: (sel) {
                    if (!sel) return;
                    widget.engine.setPresetSortMode(m.key).then((_) {
                      if (mounted) _refreshPresets();
                    });
                  },
                  selectedColor: SpotiTheme.greenTint,
                  checkmarkColor: SpotiTheme.green,
                  backgroundColor: SpotiTheme.surface2,
                  side: BorderSide(
                    color:
                        isActive ? SpotiTheme.greenStroke : SpotiTheme.stroke,
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isActive ? SpotiTheme.green : SpotiTheme.muted,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  avatar: isActive && _sortMode == 'manual'
                      ? const Icon(Icons.drag_handle_rounded,
                          size: 13, color: SpotiTheme.green)
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }

  void _promptSaveCurrent() {
    _nameController.text = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1017),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SpotiTheme.stroke),
        ),
        title: const Text('Save Loop Preset',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.engine.currentTrack?.title ?? 'Unknown Track'} · ${LoopEngine.formatTime(widget.engine.startMarkerMs ?? 0)} – ${LoopEngine.formatTime(widget.engine.endMarkerMs ?? 0)}',
              style: const TextStyle(fontSize: 12, color: SpotiTheme.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Preset name (e.g. Guitar Solo, Chorus)',
                hintStyle:
                    const TextStyle(color: SpotiTheme.faint, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF050608),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SpotiTheme.insetRadius),
                  borderSide: const BorderSide(color: SpotiTheme.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SpotiTheme.insetRadius),
                  borderSide: const BorderSide(
                      color: SpotiTheme.greenStroke, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: SpotiTheme.muted),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.engine.saveCurrentAsPreset(_nameController.text);
              if (mounted) {
                Navigator.pop(context);
                _refreshPresets();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotiTheme.green,
              foregroundColor: SpotiTheme.onGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _renamePreset(BuildContext context, LoopPreset preset) async {
    _nameController.text = preset.name;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1017),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SpotiTheme.stroke),
        ),
        title: const Text('Edit Preset Name',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2)),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Preset name',
            hintStyle: const TextStyle(color: SpotiTheme.faint, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF050608),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SpotiTheme.insetRadius),
              borderSide: const BorderSide(color: SpotiTheme.stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SpotiTheme.insetRadius),
              borderSide:
                  const BorderSide(color: SpotiTheme.greenStroke, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: SpotiTheme.muted),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotiTheme.green,
              foregroundColor: SpotiTheme.onGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      await widget.engine.editPresetName(preset, result);
      _refreshPresets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTrackId = widget.engine.currentTrack?.id;
    final canSaveCurrent = widget.engine.currentTrack != null &&
        widget.engine.startMarkerMs != null &&
        widget.engine.endMarkerMs != null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0F15),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SpotiTheme.surface3,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bookmark_rounded,
                              size: 17, color: SpotiTheme.green),
                          const SizedBox(width: 8),
                          const Text(
                            'Saved Loop Presets',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: SpotiTheme.greenTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              engineCountText,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: SpotiTheme.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.engine.userName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            'Saved for ${widget.engine.userName}',
                            style: const TextStyle(
                                fontSize: 11, color: SpotiTheme.faint),
                          ),
                        ),
                    ],
                  ),
                ),
                if (canSaveCurrent)
                  ElevatedButton.icon(
                    onPressed: _promptSaveCurrent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpotiTheme.green,
                      foregroundColor: SpotiTheme.onGreen,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      overlayColor: Colors.white.withOpacity(0.08),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Save Current',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: SpotiTheme.stroke),
          const SizedBox(height: 12),
          // Sort bar
          _sortChips(),
          const SizedBox(height: 12),
          // List
          Expanded(
            child: _presets.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _sortMode == 'manual'
                            ? Icons.drag_indicator_rounded
                            : Icons.bookmark_border_rounded,
                        size: 44,
                        color: SpotiTheme.surface3,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _sortMode == 'manual'
                            ? 'Nothing to arrange yet'
                            : 'No saved loops yet',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Set Point A & B on any song, then tap Save Current',
                        style:
                            TextStyle(color: SpotiTheme.faint, fontSize: 11.5),
                      ),
                    ],
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                    itemCount: _presets.length,
                    onReorder: (oldIndex, newIndex) {
                      if (_sortMode != 'manual') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Switch to Custom Order, then drag to arrange'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Color(0xFF10141B),
                            duration: Duration(milliseconds: 1800),
                          ),
                        );
                        return;
                      }
                      if (newIndex > oldIndex) newIndex--;
                      setState(() {
                        final item = _presets.removeAt(oldIndex);
                        _presets.insert(newIndex, item);
                      });
                      widget.engine.reorderPresets(List.of(_presets));
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final t = Curves.easeOut.transform(animation.value);
                          return Transform(
                            transform: Matrix4.identity()
                              ..translate(0.0, 2.0 * t, 0.0)
                              ..scale(1.0 + 0.02 * t, 1.0 + 0.02 * t, 1.0),
                            child: child,
                          );
                        },
                      );
                    },
                    itemBuilder: (context, index) {
                      final preset = _presets[index];
                      final isMatchingCurrent = currentTrackId != null &&
                          preset.trackId == currentTrackId;

                      return Container(
                        key: ValueKey(preset.id),
                        margin: const EdgeInsets.only(bottom: 7),
                        decoration: BoxDecoration(
                          color: SpotiTheme.surface1,
                          borderRadius:
                              BorderRadius.circular(SpotiTheme.insetRadius + 1),
                          border: Border.all(
                            color: isMatchingCurrent
                                ? SpotiTheme.greenStroke
                                : SpotiTheme.stroke,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            widget.engine.applyPreset(preset);
                            if (context.mounted) Navigator.pop(context);
                          },
                          borderRadius:
                              BorderRadius.circular(SpotiTheme.insetRadius + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                // Manual-drag handle
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    width: 24,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _sortMode == 'manual'
                                          ? SpotiTheme.surface3
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        size: 14,
                                        color: _sortMode == 'manual'
                                            ? SpotiTheme.green
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                                // Preset index dot
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: SpotiTheme.greenTint,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${(preset.sortOrder + 1).toString()}',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: SpotiTheme.green,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              preset.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${LoopEngine.formatTime(preset.startMs)} – ${LoopEngine.formatTime(preset.endMs)} · ${preset.trackTitle}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: isMatchingCurrent
                                                    ? SpotiTheme.green
                                                    : SpotiTheme.muted,
                                                fontWeight: isMatchingCurrent
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Actions
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded,
                                      color: SpotiTheme.faint, size: 19),
                                  tooltip: 'Preset options',
                                  color: const Color(0xFF0D1017),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(
                                        color: SpotiTheme.stroke),
                                  ),
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'apply':
                                        widget.engine.applyPreset(preset);
                                        if (context.mounted)
                                          Navigator.pop(context);
                                        break;
                                      case 'rename':
                                        await _renamePreset(context, preset);
                                        break;
                                      case 'delete':
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor:
                                                const Color(0xFF0D1017),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              side: const BorderSide(
                                                  color: SpotiTheme.stroke),
                                            ),
                                            title: const Text('Delete preset?',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15.5,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            content: Text(
                                              'Remove "${preset.name}"?',
                                              style: const TextStyle(
                                                  color: SpotiTheme.muted,
                                                  fontSize: 13),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        SpotiTheme.muted),
                                                child: const Text('Cancel',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      SpotiTheme.pointB,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              999)),
                                                ),
                                                child: const Text('Delete',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true &&
                                            context.mounted) {
                                          await widget.engine
                                              .deletePreset(preset.id);
                                          _refreshPresets();
                                        }
                                        break;
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'apply',
                                      height: 40,
                                      child: Row(
                                        children: [
                                          Icon(Icons.play_circle_fill_rounded,
                                              color: SpotiTheme.green,
                                              size: 17),
                                          SizedBox(width: 10),
                                          Text('Apply & jump',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'rename',
                                      height: 40,
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_rounded,
                                              color: SpotiTheme.muted,
                                              size: 17),
                                          SizedBox(width: 10),
                                          Text('Rename',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      height: 40,
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded,
                                              color: SpotiTheme.pointB,
                                              size: 17),
                                          SizedBox(width: 10),
                                          Text('Delete',
                                              style: TextStyle(
                                                  color: SpotiTheme.pointB,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String get engineCountText {
    final n = widget.engine.presets.length;
    return '$n';
  }
}
