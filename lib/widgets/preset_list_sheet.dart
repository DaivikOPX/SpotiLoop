import 'package:flutter/material.dart';
import '../models/loop_preset.dart';
import '../services/loop_engine.dart';
import '../services/storage_service.dart';

class PresetListSheet extends StatefulWidget {
  final LoopEngine engine;
  final StorageService storage;

  const PresetListSheet({super.key, required this.engine, required this.storage});

  @override
  State<PresetListSheet> createState() => _PresetListSheetState();
}

class _PresetListSheetState extends State<PresetListSheet> {
  late List<LoopPreset> _presets;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshPresets();
  }

  void _refreshPresets() {
    setState(() {
      _presets = widget.storage.getPresets();
    });
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
              '${widget.engine.currentTrack?.title ?? "Unknown Track"} (${LoopEngine.formatTime(widget.engine.startMarkerMs ?? 0)} - ${LoopEngine.formatTime(widget.engine.endMarkerMs ?? 0)})',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saved Loop Presets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                  label: const Text('Save Current', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_presets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: const [
                  Icon(Icons.bookmark_border_rounded, size: 48, color: Colors.white24),
                  SizedBox(height: 12),
                  Text(
                    'No saved loops yet',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Set Point A & B on any song and tap Save Current',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _presets.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final preset = _presets[index];
                  final isMatchingCurrent = currentTrackId != null && preset.trackId == currentTrackId;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isMatchingCurrent
                            ? const Color(0xFF1DB954).withOpacity(0.2)
                            : const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.repeat_rounded,
                        color: isMatchingCurrent ? const Color(0xFF1DB954) : Colors.white54,
                      ),
                    ),
                    title: Text(
                      preset.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    subtitle: Text(
                      '${preset.trackTitle} • ${LoopEngine.formatTime(preset.startMs)} ➔ ${LoopEngine.formatTime(preset.endMs)}',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF1DB954)),
                          tooltip: 'Apply & Jump',
                          onPressed: () {
                            widget.engine.applyPreset(preset);
                            Navigator.pop(context);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                          tooltip: 'Delete',
                          onPressed: () async {
                            await widget.storage.deletePreset(preset.id);
                            _refreshPresets();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
