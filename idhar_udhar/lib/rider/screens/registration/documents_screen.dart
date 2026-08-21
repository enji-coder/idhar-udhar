import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/dummy/dummy_rider_data.dart';
import '../../data/models/rider_document.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_bottom_sheet.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_section_header.dart';

enum _UploadSource { camera, gallery, file }

const Set<String> _allowedExtensions = <String>{
  'pdf',
  'jpg',
  'jpeg',
  'png',
};

class _DocType {
  const _DocType({
    required this.title,
    required this.kinds,
    required this.icon,
  });

  final String title;
  final List<RiderDocumentKind> kinds;
  final IconData icon;
}

const List<_DocType> _docTypes = <_DocType>[
  _DocType(
    title: 'Aadhaar Card',
    icon: Icons.badge_outlined,
    kinds: <RiderDocumentKind>[
      RiderDocumentKind.aadhaarFront,
      RiderDocumentKind.aadhaarBack,
    ],
  ),
  _DocType(
    title: 'PAN Card',
    icon: Icons.credit_card_rounded,
    kinds: <RiderDocumentKind>[RiderDocumentKind.panFront],
  ),
  _DocType(
    title: 'Driving License',
    icon: Icons.directions_car_filled_outlined,
    kinds: <RiderDocumentKind>[
      RiderDocumentKind.drivingLicenseFront,
      RiderDocumentKind.drivingLicenseBack,
    ],
  ),
  _DocType(
    title: 'RC / Vehicle Registration',
    icon: Icons.description_outlined,
    kinds: <RiderDocumentKind>[
      RiderDocumentKind.vehicleRcFront,
      RiderDocumentKind.vehicleRcBack,
    ],
  ),
  _DocType(
    title: 'Bank Proof',
    icon: Icons.account_balance_outlined,
    kinds: <RiderDocumentKind>[RiderDocumentKind.bankProof],
  ),
];

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    this.reviewMode = false,
  });

  /// When true, documents are reviewed/replaced from the menu (not registration).
  final bool reviewMode;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late List<RiderDocument> _docs;
  bool _permissionPrimed = false;

  @override
  void initState() {
    super.initState();
    _docs = List<RiderDocument>.from(
      widget.reviewMode
          ? DummyRiderData.documents
          : DummyRiderData.registrationDocuments,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _primeDocumentPermissions();
    });
  }

  Future<void> _primeDocumentPermissions() async {
    if (_permissionPrimed || kIsWeb) return;
    _permissionPrimed = true;
    final status = await Permission.camera.status;
    if (status.isDenied) {
      await Permission.camera.request();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RiderColors.secondary,
        content: Text(
          message,
          style: RiderTextStyles.bodyMedium.copyWith(
            color: RiderColors.textOnPrimary,
          ),
        ),
      ),
    );
  }

  bool _isAllowedPath(String pathOrName) {
    final lower = pathOrName.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot < 0 || dot == lower.length - 1) return false;
    return _allowedExtensions.contains(lower.substring(dot + 1));
  }

  int _indexOf(RiderDocumentKind kind) =>
      _docs.indexWhere((d) => d.kind == kind);

  bool _typeComplete(_DocType type) {
    return type.kinds.every((kind) {
      final i = _indexOf(kind);
      return i >= 0 && _docs[i].isProvided;
    });
  }

  List<String> get _missingLabels {
    return _docs
        .where((d) => d.status == RiderDocumentStatus.uploadRequired)
        .map((d) => d.kind.label)
        .toList();
  }

  bool get _canContinue => _missingLabels.isEmpty;

  Future<({String path, String name})?> _pickFile(RiderDocument doc) async {
    final source = await showRiderBottomSheet<_UploadSource>(
      context: context,
      title: 'Upload ${doc.kind.label}',
      actions: const <RiderSheetAction<_UploadSource>>[
        RiderSheetAction<_UploadSource>(
          label: 'Camera',
          icon: Icons.photo_camera_outlined,
          value: _UploadSource.camera,
        ),
        RiderSheetAction<_UploadSource>(
          label: 'Gallery',
          icon: Icons.photo_library_outlined,
          value: _UploadSource.gallery,
        ),
        RiderSheetAction<_UploadSource>(
          label: 'File',
          icon: Icons.insert_drive_file_outlined,
          value: _UploadSource.file,
        ),
      ],
    );
    if (source == null || !mounted) return null;

    String? path;
    String? name;

    switch (source) {
      case _UploadSource.file:
      case _UploadSource.gallery:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: _allowedExtensions.toList(),
          allowMultiple: false,
          withData: false,
        );
        if (result == null || result.files.isEmpty) return null;
        final file = result.files.single;
        name = file.name;
        path = file.path;
        if (name.isEmpty || !_isAllowedPath(name)) {
          _snack('Unsupported file. Use PDF, JPG, JPEG, or PNG.');
          return null;
        }
        if (path == null || path.isEmpty) {
          _snack('Could not read the selected file. Please try again.');
          return null;
        }
      case _UploadSource.camera:
        final cam = await Permission.camera.request();
        if (!cam.isGranted) {
          if (cam.isPermanentlyDenied) {
            _snack('Camera permission denied. Enable it in Settings.');
            await openAppSettings();
          } else {
            _snack('Camera permission is required to take a photo.');
          }
          return null;
        }
        final photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (photo == null) return null;
        path = photo.path;
        name = photo.name;
        if (!_isAllowedPath(name)) {
          name = '${doc.kind.name}.jpg';
        }
    }

    return (path: path, name: name);
  }

  Future<void> _openTypeSheet(_DocType type) async {
    final updated = await showModalBottomSheet<List<RiderDocument>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _DocumentSidesSheet(
          title: 'Upload ${type.title}',
          kinds: type.kinds,
          docs: _docs,
          onPick: _pickFile,
        );
      },
    );
    if (updated == null || !mounted) return;
    setState(() => _docs = updated);
  }

  void _onContinue() {
    if (!_canContinue) {
      _snack('Missing: ${_missingLabels.join(', ')}');
      return;
    }
    if (widget.reviewMode) {
      context.pop();
      return;
    }
    context.push(RiderRoutes.bankUpi);
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: widget.reviewMode ? 'Done' : 'Continue',
        enabled: _canContinue,
        onPressed: _onContinue,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Document verification', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'Select a document type to upload. Files stay on this device (dummy flow).',
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.xl),
            for (final type in _docTypes) ...[
              _DocumentTypeTile(
                type: type,
                complete: _typeComplete(type),
                onTap: () => _openTypeSheet(type),
              ),
              const SizedBox(height: RiderSpacing.md),
            ],
            if (!_canContinue)
              Text(
                'Missing: ${_missingLabels.join(', ')}',
                style: RiderTextStyles.caption.copyWith(
                  color: RiderColors.warning,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTypeTile extends StatelessWidget {
  const _DocumentTypeTile({
    required this.type,
    required this.complete,
    required this.onTap,
  });

  final _DocType type;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: RiderRadius.lgAll,
        child: RiderGlassCard(
          padding: const EdgeInsets.all(RiderSpacing.lg),
          borderRadius: RiderRadius.lgAll,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: RiderColors.primary.withValues(alpha: 0.12),
                  borderRadius: RiderRadius.mdAll,
                ),
                child: Icon(type.icon, color: RiderColors.primary),
              ),
              const SizedBox(width: RiderSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.title, style: RiderTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      type.kinds.length > 1
                          ? 'Front and back required'
                          : 'Document photo required',
                      style: RiderTextStyles.caption,
                    ),
                  ],
                ),
              ),
              RiderStatusChip(
                label: complete ? 'Uploaded' : 'Required',
                tone: complete ? RiderChipTone.success : RiderChipTone.warning,
              ),
              const SizedBox(width: RiderSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: RiderColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentSidesSheet extends StatefulWidget {
  const _DocumentSidesSheet({
    required this.title,
    required this.kinds,
    required this.docs,
    required this.onPick,
  });

  final String title;
  final List<RiderDocumentKind> kinds;
  final List<RiderDocument> docs;
  final Future<({String path, String name})?> Function(RiderDocument doc)
      onPick;

  @override
  State<_DocumentSidesSheet> createState() => _DocumentSidesSheetState();
}

class _DocumentSidesSheetState extends State<_DocumentSidesSheet> {
  late List<RiderDocument> _local;

  @override
  void initState() {
    super.initState();
    _local = List<RiderDocument>.from(widget.docs);
  }

  RiderDocument _doc(RiderDocumentKind kind) =>
      _local.firstWhere((d) => d.kind == kind);

  String _sideLabel(RiderDocumentKind kind) {
    if (widget.kinds.length == 1) return 'Document';
    final label = kind.label.toLowerCase();
    if (label.contains('back')) return 'Back';
    return 'Front';
  }

  Future<void> _upload(RiderDocumentKind kind) async {
    final current = _doc(kind);
    final picked = await widget.onPick(current);
    if (picked == null || !mounted) return;
    setState(() {
      _local = _local.map((d) {
        if (d.kind != kind) return d;
        return d.copyWith(
          status: RiderDocumentStatus.uploaded,
          fileName: picked.name,
          localPath: picked.path,
        );
      }).toList();
    });
  }

  void _submit() {
    final missing = widget.kinds.where((kind) => !_doc(kind).isProvided);
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: RiderColors.secondary,
          content: Text(
            'Upload ${missing.map((k) => _sideLabel(k)).join(' and ')} to submit.',
            style: RiderTextStyles.bodyMedium.copyWith(
              color: RiderColors.textOnPrimary,
            ),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(_local);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RiderSpacing.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RiderColors.surface,
              borderRadius: RiderRadius.xlAll,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  RiderSpacing.xl,
                  RiderSpacing.xl,
                  RiderSpacing.xl,
                  RiderSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: RiderColors.border,
                          borderRadius: RiderRadius.pillAll,
                        ),
                      ),
                    ),
                    const SizedBox(height: RiderSpacing.lg),
                    Text(widget.title, style: RiderTextStyles.title),
                    const SizedBox(height: RiderSpacing.lg),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (var i = 0; i < widget.kinds.length; i++) ...[
                              _DashedUploadSlot(
                                label: _sideLabel(widget.kinds[i]),
                                document: _doc(widget.kinds[i]),
                                onUpload: () => _upload(widget.kinds[i]),
                              ),
                              if (i < widget.kinds.length - 1)
                                const SizedBox(height: RiderSpacing.md),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: RiderSpacing.lg),
                    RiderPrimaryButton(
                      label: 'Submit',
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedUploadSlot extends StatelessWidget {
  const _DashedUploadSlot({
    required this.label,
    required this.document,
    required this.onUpload,
  });

  final String label;
  final RiderDocument document;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final preview = !kIsWeb &&
        document.localPath != null &&
        document.isImage &&
        File(document.localPath!).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: RiderTextStyles.bodyMedium),
        const SizedBox(height: RiderSpacing.sm),
        CustomPaint(
          painter: _DashedRectPainter(color: RiderColors.border),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(RiderSpacing.md),
            child: Column(
              children: [
                if (preview)
                  ClipRRect(
                    borderRadius: RiderRadius.smAll,
                    child: Image.file(
                      File(document.localPath!),
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 36,
                    color: RiderColors.primary.withValues(alpha: 0.85),
                  ),
                const SizedBox(height: RiderSpacing.sm),
                if (document.fileName != null)
                  Text(
                    document.fileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RiderTextStyles.caption,
                  ),
                const SizedBox(height: RiderSpacing.sm),
                SizedBox(
                  width: 120,
                  child: RiderPrimaryButton(
                    label: 'Upload',
                    onPressed: onUpload,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(RiderRadius.md),
        ),
      );
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next.toDouble()), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
