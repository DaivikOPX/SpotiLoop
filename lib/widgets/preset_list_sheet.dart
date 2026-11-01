import 'package:flutter/material.dart';
import '../models/loop_preset.dart';
import '../services/loop_engine.dart';

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
      ..sort((a, b) => a.key == _sortMode ? -1 : a.key == _sortMode ? 1 : 0);
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
                  selectedColor: const Color(0xFF1DB954).withOpacity(0.25),
                  checkmarkColor: const Color(0xFF1DB954),
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isActive ? const Color(0xFF1DB954) : Colors.white70,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  avatar: isActive && _sortMode == 'manual'
                      ? const Icon(Icons.drag_handle, size: 15, color: Color(0xFF1DB954))
                      : null,
                  side: BorderSide(
                    color: isActive ? const Color(0xFF1DB954) : Colors.white24,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        backgroundColor: const Color(0xFF222222),
        title: const Text('Save Loop Preset', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.engine.currentTrack?.title ?? 'Unknown Track'} (${LoopEngine.formatTime(widget.engine.startMarkerMs ?? 0)} - ${LoopEngine.formatTime(widget.engine.endMarkerMs ?? 0)})',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Preset Name (e.g. Guitar Solo, Chorus)',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF181818),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
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
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
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
        backgroundColor: const Color(0xFF222222),
        title: const Text('Edit Preset Name', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 280,
          child: TextField(
            controller: _nameController,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Preset Name',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Color(0xFF181818),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bookmark_rounded, size: 18, color: Color(0xFF1DB954)),
                        const SizedBox(width: 8),
                        const Text(
                          'Saved Loop Presets',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    if (widget.engine.userName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Saved for: ${widget.engine.userName}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9E9EA8)),
                        ),
                      ),
                  ],
                ),
              ),
              if (canSaveCurrent)
                ElevatedButton.icon(
                  onPressed: _promptSaveCurrent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Save Current', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Sort bar
          _sortChips(),
          const SizedBox(height: 12),
          // List
          if (_presets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Icon(
                    _sortMode == 'manual' ? Icons.drag_indicator_rounded : Icons.bookmark_border_rounded,
                    size: 44,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _sortMode == 'manual'
                        ? 'No presets yet — drag to arrange'
                        : 'No saved loops yet',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set Point A & B on any song and tap Save Current',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _presets.length,
              onReorder: (oldIndex, newIndex) {
                if (_sortMode != 'manual') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switch to Custom Order, then drag to arrange'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF14151E),
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
              },
              itemBuilder: (context, index) {
                final preset = _presets[index];
                final isMatchingCurrent =
                    currentTrackId != null && preset.trackId == currentTrackId;

                return Card(
                  key: ValueKey(preset.id),
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: const Color(0xFF20212A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () {
                      widget.engine.applyPreset(preset);
                      if (context.mounted) Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          // Manual-drag handle
                          ReorderableDragStartListener(
                            index: index,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _sortMode == 'manual'
                                    ? const Color(0xFF1DB954).withOpacity(0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: _sortMode == 'manual'
                                  ? const Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 14,
                                      color: Color(0xFF1DB954),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Thumbnail / icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isMatchingCurrent
                                  ? const Color(0xFF1DB954).withOpacity(0.2)
                                  : const Color(0xFF2C2E3A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (_sortMode == 'manual' && preset.sortOrder == index)
                                    ? const Color(0xFF1DB954)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                preset.name.isNotEmpty ? preset.name.substring(0, 1).toUpperCase() : '?',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Name + range + track
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preset.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${LoopEngine.formatTime(preset.startMs)} → ${LoopEngine.formatTime(preset.endMs)}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF9E9EA8)),
                                ),
                                Text(
                                  preset.trackTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isMatchingCurrent ? const Color(0xFF1DB954) : Colors.white38,
                                    fontWeight: isMatchingCurrent ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Actions
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF9E9EA8), size: 20),
                            tooltip: 'Preset options',
                            color: const Color(0xFF222222),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            onSelected: (value) async {
                              switch (value) {
                                case 'rename':
                                  await _renamePreset(context, preset);
                                  break;
                                case 'apply':
                                  widget.engine.applyPreset(preset);
                                  if (context.mounted) Navigator.pop(context);
                                  break;
                                case 'delete':
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF222222),
                                      title: const Text('Delete preset?', style: TextStyle(color: Colors.white)),
                                      content: Text(
                                        'Remove "${preset.name}"?',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFE53935),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    await widget.engine.deletePreset(preset.id);
                                    _refreshPresets();
                                  }
                                  break;
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'apply', child: Row(
                                children: [
                                  Icon(Icons.play_circle_filled_rounded, color: Color(0xFF1DB954), size: 18),
                                  SizedBox(width: 10),
                                  Text('Apply & Jump', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                                ],
                              )),
                              PopupMenuItem(value: 'rename', child: Row(
                                children: [
                                  Icon(Icons.edit_rounded, color: Color(0xFF9E9EA8), size: 18),
                                  SizedBox(width: 10),
                                  Text('Rename', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                                ],
                              )),
                              PopupMenuItem(value: 'delete', child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252), size: 18),
                                  SizedBox(width: 10),
                                  Text('Delete', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w600, fontSize: 12.5)),
                                ],
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
