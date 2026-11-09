import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/finance.dart';
import '../domain/models.dart';
import 'attachments_block.dart';
import 'components.dart';
import 'forms.dart';
import 'legacy_screens.dart';
import 'security_screens.dart';
import 'widgets.dart';
import 'wealth_screens.dart';

/// Shows the full context of a single ledger entry (E05). Offers a reverse
/// action only when the entry is not itself a reversal and has not already
/// been reversed.
class TransactionDetailScreen extends StatelessWidget {
  final PortfolioStore store;
  final LedgerEvent event;
  const TransactionDetailScreen(
      {super.key, required this.store, required this.event});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final current = store.state.events
            .firstWhere((e) => e.id == event.id, orElse: () => event);
        final reversed = eventIsReversed(current, store.state.events);
        final reversal = current.kind == EventKind.reversal
            ? store.state.events.firstWhere(
                (e) => e.id == current.reversalOf,
                orElse: () => current)
            : null;
        final linkedAsset = current.assetId == null
            ? null
            : store.state.assets.firstWhere(
                (a) => a.id == current.assetId,
                orElse: () => WealthAsset(
                    id: current.assetId!,
                    name: 'Archived asset',
                    kind: AssetKind.other,
                    valueUgx: 0,
                    valuedAt: DateTime(1970)));

        return WealthPage(
            title: 'Transaction',
            subtitle: current.description,
            children: [
              SoftCard(
                  color: current.kind == EventKind.reversal
                      ? const Color(0xFFF8EAE7)
                      : LG.sageSoft,
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: LG.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(_iconFor(current.kind),
                          color:
                              current.kind == EventKind.reversal ? LG.negative : LG.sage),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(current.kind.name,
                              style: const TextStyle(
                                  color: LG.muted,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(LG.money(current.amountUgx),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 20)),
                        ])),
                    if (reversed) const StatusChip(label: 'Reversed', tone: StatusTone.danger)
                  ])),
              const SizedBox(height: 18),
              SoftCard(
                  child: Column(children: [
                InfoLabel(label: 'Recorded on', value: LG.date(current.occurredAt)),
                InfoLabel(label: 'Entry type', value: current.kind.name),
                if (linkedAsset != null)
                  InfoLabel(label: 'Linked asset', value: linkedAsset.name),
                if (current.notes.isNotEmpty)
                  InfoLabel(label: 'Notes', value: current.notes),
                if (current.reversalOf != null && reversal != null)
                  InfoLabel(
                      label: 'Reverses entry',
                      value: reversal.description),
              ])),
              if (!reversed && current.kind != EventKind.reversal) ...[
                const SizedBox(height: 20),
                PrimaryCTA(
                  label: 'Reverse this entry',
                  showArrow: false,
                  onPressed: () async {
                    final confirm = await confirmActionSheet(context,
                        title: 'Append a reversal?',
                        consequence:
                            'The original entry stays in the ledger. A new reversal entry will be appended so totals reconcile.',
                        confirmLabel: 'Append reversal');
                    if (!confirm) return;
                    try {
                      await store.reverseEvent(current);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not reverse: $e')));
                    }
                  },
                ),
              ],
              if (current.kind == EventKind.reversal) ...[
                const SizedBox(height: 16),
                const SecurityNotice(
                  title: 'This is a reversal entry',
                  message:
                      'Reversal entries exist to document corrections. They are append-only and cannot themselves be reversed.',
                  icon: Icons.info_outline,
                ),
              ],
              const SizedBox(height: 18),
              AttachmentsBlock(
                title: 'Receipts & evidence',
                helpText:
                    'Attach the receipt, statement screenshot or confirmation for this entry. Stored encrypted on this device.',
                store: store,
                attachments: current.attachments,
                onAdd: ({required bytes,
                        required filename,
                        required mimeType}) =>
                    store.addEventAttachment(
                        eventId: current.id,
                        bytes: bytes,
                        filename: filename,
                        mimeType: mimeType),
                onRemove: (i) =>
                    store.removeEventAttachment(current.id, i),
              ),
              const SizedBox(height: 18),
              const Text(
                  'The transaction ledger is append-only. Every reversal preserves the original entry so audit history stays intact. Attachments are metadata and can be added or removed after posting.',
                  style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5)),
            ]);
      });

  static IconData _iconFor(EventKind kind) => switch (kind) {
        EventKind.contribution => Icons.input,
        EventKind.withdrawal => Icons.output,
        EventKind.dividend => Icons.payments_outlined,
        EventKind.interest => Icons.percent_rounded,
        EventKind.rent => Icons.home_work_outlined,
        EventKind.fee => Icons.monetization_on_outlined,
        EventKind.tax => Icons.receipt_long_outlined,
        EventKind.expense => Icons.shopping_cart_outlined,
        EventKind.transfer => Icons.swap_horiz,
        EventKind.adjustment => Icons.tune,
        EventKind.reversal => Icons.undo,
      };
}

/// Liability detail screen (E02) accessed by tapping a row on DebtsScreen
/// or from the portfolio search. Keeps edit + archive discoverable without
/// requiring the user to go through the form each time.
class LiabilityDetailScreen extends StatelessWidget {
  final PortfolioStore store;
  final Liability liability;
  const LiabilityDetailScreen(
      {super.key, required this.store, required this.liability});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final current = store.state.liabilities.firstWhere(
            (l) => l.id == liability.id,
            orElse: () => liability);
        final linkedProperty = current.propertyId == null
            ? null
            : store.state.assets.firstWhere(
                (a) => a.id == current.propertyId,
                orElse: () => WealthAsset(
                    id: current.propertyId!,
                    name: 'Archived property',
                    kind: AssetKind.property,
                    valueUgx: 0,
                    valuedAt: DateTime(1970)));
        return WealthPage(
            title: 'Liability',
            subtitle: current.name,
            children: [
              SoftCard(
                  color: LG.navy,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('OUTSTANDING BALANCE',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(LG.money(current.outstandingUgx),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('As of ${LG.date(current.asOf)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
              const SizedBox(height: 18),
              SoftCard(
                  child: Column(children: [
                if (current.lender.isNotEmpty)
                  InfoLabel(label: 'Lender', value: current.lender),
                if (current.principalUgx > 0)
                  InfoLabel(
                      label: 'Original principal',
                      value: LG.money(current.principalUgx)),
                if (current.dueAt != null)
                  InfoLabel(label: 'Due', value: LG.date(current.dueAt!)),
                if (linkedProperty != null)
                  InfoLabel(
                      label: 'Linked property', value: linkedProperty.name),
                if (current.notes.isNotEmpty)
                  InfoLabel(label: 'Notes', value: current.notes),
                InfoLabel(
                    label: 'Archived',
                    value: current.archived ? 'Yes' : 'No',
                    valueColor:
                        current.archived ? LG.negative : LG.navy),
              ])),
              if (linkedProperty != null) ...[
                const SizedBox(height: 14),
                const SecurityNotice(
                  title: 'Linked mortgage',
                  message:
                      'Because this liability is linked to a property, net worth already subtracts it once from the owner-attributable property value. It is not double-counted.',
                  icon: Icons.account_balance_outlined,
                ),
              ],
              const SizedBox(height: 22),
              PrimaryCTA(
                label: 'Edit liability',
                showArrow: false,
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => LiabilityForm(store: store, existing: current)));
                },
              ),
              const SizedBox(height: 10),
              if (!current.archived)
                TextButton(
                    onPressed: () async {
                      final confirm = await confirmActionSheet(context,
                          title: 'Archive this liability?',
                          consequence:
                              'Archived liabilities are excluded from net worth. You can restore them from Settings → Archived records.',
                          confirmLabel: 'Archive');
                      if (!confirm) return;
                      await store.archiveLiability(current);
                      if (!context.mounted) return;
                      Navigator.of(context).maybePop();
                    },
                    child: const Text('Archive liability',
                        style: TextStyle(color: LG.negative)))
              else
                TextButton(
                    onPressed: () async {
                      await store.restoreLiability(current);
                      if (!context.mounted) return;
                      Navigator.of(context).maybePop();
                    },
                    child: const Text('Restore liability',
                        style: TextStyle(color: LG.sage))),
            ]);
      });
}

/// Document record detail landing (G09). Metadata, renewal context, linked
/// asset and the full encrypted-attachment lifecycle (attach, decrypt +
/// preview, remove) live here rather than inside the metadata form.
class DocumentDetailScreen extends StatefulWidget {
  final PortfolioStore store;
  final DocumentRecord document;
  const DocumentDetailScreen(
      {super.key, required this.store, required this.document});
  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _busy = false;

  DocumentRecord get _current =>
      widget.store.state.documents.firstWhere((d) => d.id == widget.document.id,
          orElse: () => widget.document);

  Future<void> _pickAttachment(DocumentRecord current) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The file could not be read from the picker.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.attachFile(current, bytes,
          filename: file.name,
          mimeType: file.extension == null
              ? 'application/octet-stream'
              : _mimeFor(file.extension!));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not attach: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewAttachment(AttachmentRef ref) async {
    setState(() => _busy = true);
    try {
      final tmp = await widget.store.attachments
          .materialize(ref, key: widget.store.vault.activeKey);
      await OpenFilex.open(tmp.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open attachment: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAttachment(DocumentRecord current) async {
    if (current.attachment == null) return;
    final confirm = await confirmActionSheet(context,
        title: 'Remove this attachment?',
        consequence:
            'The encrypted file is deleted from this device. Metadata for the record is kept so you can attach a new one later.',
        confirmLabel: 'Remove file');
    if (!confirm) return;
    setState(() => _busy = true);
    try {
      await widget.store.removeAttachment(current);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive(DocumentRecord current) async {
    final confirm = await confirmActionSheet(context,
        title: 'Archive this document record?',
        consequence:
            'Archived records disappear from the main list but are recoverable from Settings → Archived records.',
        confirmLabel: 'Archive');
    if (!confirm) return;
    await widget.store.archiveDocument(current);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final current = _current;
        final attachment = current.attachment;
        final now = DateTime.now();
        final linkedAsset = current.linkedAssetId == null
            ? null
            : widget.store.state.assets.firstWhere(
                (a) => a.id == current.linkedAssetId,
                orElse: () => WealthAsset(
                    id: current.linkedAssetId!,
                    name: 'Archived asset',
                    kind: AssetKind.other,
                    valueUgx: 0,
                    valuedAt: DateTime(1970)));
        final expires = current.expiresAt;
        final overdue = expires != null && expires.isBefore(now);
        final soon = expires != null &&
            !overdue &&
            expires.difference(now).inDays <= 30;
        return WealthPage(
            title: 'Document record',
            subtitle: current.title,
            children: [
              SoftCard(
                  color: LG.sageSoft,
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          color: LG.white,
                          borderRadius: BorderRadius.circular(14)),
                      child: Icon(
                          attachment == null
                              ? Icons.description_outlined
                              : Icons.lock,
                          color: LG.sage),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(current.category,
                              style: const TextStyle(
                                  color: LG.sage,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(current.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                        ])),
                    if (overdue)
                      const StatusChip(label: 'Expired', tone: StatusTone.danger)
                    else if (soon)
                      const StatusChip(label: 'Renew soon', tone: StatusTone.warn)
                    else if (current.archived)
                      const StatusChip(
                          label: 'Archived', tone: StatusTone.neutral),
                  ])),
              const SizedBox(height: 18),
              SoftCard(
                  child: Column(children: [
                if (current.issuedAt != null)
                  InfoLabel(label: 'Issued', value: LG.date(current.issuedAt!)),
                if (current.expiresAt != null)
                  InfoLabel(
                      label: 'Expires / renews',
                      value: LG.date(current.expiresAt!),
                      valueColor: overdue ? LG.negative : null),
                if (linkedAsset != null)
                  InfoLabel(label: 'Linked asset', value: linkedAsset.name),
                if (current.notes.isNotEmpty)
                  InfoLabel(label: 'Notes', value: current.notes),
              ])),
              const SizedBox(height: 18),
              const SectionTitle('Encrypted attachment'),
              if (attachment == null)
                SoftCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          widget.store.vault.hasPassphrase
                              ? 'No file attached yet. Attachments picked here are AES-GCM encrypted under your vault key before writing to disk.'
                              : 'No file attached yet. Attachments are encrypted on disk with a per-file key. Enable a passphrase from More → Encryption to bind them to your vault.',
                          style: const TextStyle(
                              color: LG.muted, fontSize: 12, height: 1.5)),
                      const SizedBox(height: 14),
                      PrimaryCTA(
                        label: _busy ? 'Encrypting…' : 'Attach encrypted file',
                        loading: _busy,
                        showArrow: false,
                        onPressed: () async => _pickAttachment(current),
                      ),
                    ]))
              else
                SoftCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        const Icon(Icons.lock, color: LG.sage),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(attachment.originalFilename,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '${_sizeHuman(attachment.sizeBytes)} · ${attachment.mimeType}',
                                  style: const TextStyle(
                                      color: LG.muted, fontSize: 12)),
                              const SizedBox(height: 4),
                              _AttachmentSyncBadge(
                                  uploaded: attachment.serverId != null),
                            ])),
                        IconButton(
                            tooltip: 'Remove file',
                            onPressed:
                                _busy ? null : () => _removeAttachment(current),
                            icon: const Icon(Icons.delete_outline,
                                color: LG.muted)),
                      ]),
                      const SizedBox(height: 12),
                      PrimaryCTA(
                          label: _busy ? 'Decrypting…' : 'Decrypt and preview',
                          loading: _busy,
                          showArrow: false,
                          onPressed: () async => _viewAttachment(attachment)),
                      const SizedBox(height: 10),
                      Text(
                          'SHA-256 ${attachment.sha256Hex.substring(0, 12)}… · attached ${LG.date(attachment.addedAt)}',
                          style: const TextStyle(
                              color: LG.muted, fontSize: 11)),
                    ])),
              const SizedBox(height: 18),
              SoftCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => EncryptionSetupScreen(store: widget.store))),
                  child: Row(children: [
                    Icon(
                        widget.store.vault.hasPassphrase
                            ? Icons.lock
                            : Icons.lock_open,
                        color: LG.sage),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text('Manage encryption',
                            style: TextStyle(fontWeight: FontWeight.w700))),
                    const Icon(Icons.chevron_right, color: LG.muted),
                  ])),
              const SizedBox(height: 22),
              PrimaryCTA(
                  label: 'Edit metadata',
                  showArrow: false,
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) =>
                            DocumentFormScreen(store: widget.store, existing: current)));
                  }),
              const SizedBox(height: 10),
              if (!current.archived)
                TextButton(
                    onPressed: () => _archive(current),
                    child: const Text('Archive record',
                        style: TextStyle(color: LG.negative)))
              else
                TextButton(
                    onPressed: () async {
                      await widget.store.restoreDocument(current);
                    },
                    child: const Text('Restore record',
                        style: TextStyle(color: LG.sage))),
            ]);
      });

  static String _mimeFor(String ext) => switch (ext.toLowerCase()) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'txt' => 'text/plain',
        'csv' => 'text/csv',
        _ => 'application/octet-stream',
      };

  static String _sizeHuman(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Small pill that tells the user whether an attachment still only lives on
/// this device or has been copied to the backend. Mirrors the serverId flag
/// on the AttachmentRef — populated only after the three-phase sync commits.
class _AttachmentSyncBadge extends StatelessWidget {
  final bool uploaded;
  const _AttachmentSyncBadge({required this.uploaded});

  @override
  Widget build(BuildContext context) {
    final Color bg = uploaded ? LG.sageSoft : const Color(0xFFF2EFE5);
    final Color fg = uploaded ? LG.sage : LG.gold;
    final IconData icon =
        uploaded ? Icons.cloud_done_outlined : Icons.phone_iphone_rounded;
    final String label = uploaded ? 'Uploaded to backend' : 'Local only';
    return Semantics(
      label: 'Attachment sync status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
