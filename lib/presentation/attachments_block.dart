import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/models.dart';
import 'widgets.dart';

/// Shared block that lists a set of attachments and offers three attach
/// actions (Scan, Gallery, File). Owner-agnostic — the caller supplies
/// the current list and callbacks for add + remove + preview. Used on
/// AssetDetails and TransactionDetailScreen (and anywhere else that
/// needs encrypted-at-rest file collections).
class AttachmentsBlock extends StatefulWidget {
  final String title;
  final String helpText;
  final PortfolioStore store;
  final List<AttachmentRef> attachments;
  final Future<AttachmentRef> Function(
      {required List<int> bytes,
      required String filename,
      required String mimeType}) onAdd;
  final Future<void> Function(int index) onRemove;
  const AttachmentsBlock({
    super.key,
    required this.title,
    required this.helpText,
    required this.store,
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<AttachmentsBlock> createState() => _AttachmentsBlockState();
}

class _AttachmentsBlockState extends State<AttachmentsBlock> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final list = widget.attachments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(widget.title),
        if (list.isEmpty)
          const SoftCard(
            padding: EdgeInsets.all(14),
            color: LG.sageSoft,
            child: Row(children: [
              Icon(Icons.description_outlined, color: LG.sage),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                    'No files yet. Scan a receipt, pick from the gallery, or attach a statement PDF.',
                    style: TextStyle(color: LG.muted, fontSize: 13)),
              ),
            ]),
          ),
        for (var i = 0; i < list.length; i += 1) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              onTap: _busy ? null : () => _preview(list[i]),
              child: Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: LG.goldSoft,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.attachment_rounded,
                        color: LG.gold, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list[i].originalFilename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                            '${_sizeHuman(list[i].sizeBytes)} · ${list[i].mimeType}',
                            style: const TextStyle(
                                color: LG.muted, fontSize: 11.5)),
                      ]),
                ),
                IconButton(
                  tooltip: 'Preview',
                  onPressed:
                      _busy ? null : () => _preview(list[i]),
                  icon: const Icon(Icons.open_in_new, color: LG.sage),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await widget.onRemove(i);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon:
                      const Icon(Icons.delete_outline, color: LG.muted),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _attachFromCamera,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _attachFromGallery,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Gallery'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _attachFromFile,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('File'),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(widget.helpText,
            style: const TextStyle(
                color: LG.muted, fontSize: 12, height: 1.45)),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!,
              style: const TextStyle(color: LG.negative, fontSize: 12)),
        ],
        if (_busy) ...[
          const SizedBox(height: 6),
          const LinearProgressIndicator(
              minHeight: 3,
              color: LG.sage,
              backgroundColor: LG.sageSoft),
        ],
      ],
    );
  }

  Future<void> _attachFromCamera() async {
    await _tryPick(() async {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 85);
      return shot == null
          ? null
          : _PickedFile(path: shot.path, name: shot.name, mime: 'image/jpeg');
    });
  }

  Future<void> _attachFromGallery() async {
    await _tryPick(() async {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      return shot == null
          ? null
          : _PickedFile(path: shot.path, name: shot.name, mime: 'image/jpeg');
    });
  }

  Future<void> _attachFromFile() async {
    await _tryPick(() async {
      final pick = await FilePicker.platform
          .pickFiles(type: FileType.any, withData: false);
      final file = pick?.files.single;
      if (file == null || file.path == null) return null;
      return _PickedFile(
          path: file.path!,
          name: file.name,
          mime: _guessMime(file.name));
    });
  }

  Future<void> _tryPick(
      Future<_PickedFile?> Function() pickAction) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await pickAction();
      if (file != null) {
        HapticFeedback.selectionClick();
        final bytes = await File(file.path).readAsBytes();
        await widget.onAdd(
            bytes: bytes, filename: file.name, mimeType: file.mime);
      }
    } on PlatformException catch (e) {
      setState(() => _error =
          'Could not access source: ${e.message ?? e.code}');
    } catch (e) {
      setState(() => _error = 'Attach failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(AttachmentRef ref) async {
    try {
      final tmp = await widget.store.attachments
          .materialize(ref, key: widget.store.vault.activeKey);
      await OpenFilex.open(tmp.path);
    } catch (e) {
      setState(() => _error = 'Could not preview: $e');
    }
  }

  static String _guessMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      'doc' || 'docx' => 'application/msword',
      'xls' || 'xlsx' => 'application/vnd.ms-excel',
      _ => 'application/octet-stream',
    };
  }

  static String _sizeHuman(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _PickedFile {
  final String path;
  final String name;
  final String mime;
  _PickedFile({required this.path, required this.name, required this.mime});
}
