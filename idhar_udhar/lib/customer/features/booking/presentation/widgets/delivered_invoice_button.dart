import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/customer/core/constants/asset_paths.dart';
import 'package:idhar_udhar/customer/core/theme/theme.dart';
import 'package:idhar_udhar/customer/core/widgets/secondary_button.dart';
import 'package:idhar_udhar/customer/features/booking/data/customer_invoice.dart';
import 'package:idhar_udhar/customer/features/booking/data/customer_invoice_pdf.dart';
import 'package:idhar_udhar/customer/shared/widgets/custom_snack_bar.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final customerInvoiceProvider =
    FutureProvider.autoDispose.family<CustomerInvoice?, String>((
  Ref ref,
  String orderId,
) async {
  try {
    return CustomerInvoice.fromJson(
      await ref.watch(ordersApiProvider).getInvoice(orderId),
    );
  } on ApiException catch (error) {
    if (error.statusCode == 404 || error.statusCode == 409) {
      return null;
    }
    rethrow;
  }
});

/// Shown only for a delivered order. The button itself appears after the
/// stored invoice is returned.
class DeliveredInvoiceButton extends ConsumerStatefulWidget {
  const DeliveredInvoiceButton({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<DeliveredInvoiceButton> createState() =>
      _DeliveredInvoiceButtonState();
}

class _DeliveredInvoiceButtonState extends ConsumerState<DeliveredInvoiceButton> {
  bool _saving = false;

  Future<void> _download(CustomerInvoice invoice) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final ByteData logo = await rootBundle.load(AssetPaths.logo);
      final Uint8List bytes = await buildCustomerInvoicePdf(
        invoice: invoice,
        logoBytes: logo.buffer.asUint8List(),
      );
      final Directory directory = await getTemporaryDirectory();
      final String name = invoice.invoiceNumber.replaceAll(RegExp(r'[^\w.-]'), '_');
      final File file = File('${directory.path}/$name.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        <XFile>[XFile(file.path, mimeType: 'application/pdf', name: '$name.pdf')],
        subject: 'IDHAR UDHAR invoice ${invoice.invoiceNumber}',
      );
    } catch (error) {
      if (mounted) {
        CustomSnackBar.error(context, 'Could not prepare the invoice PDF.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CustomerInvoice?> invoice =
        ref.watch(customerInvoiceProvider(widget.orderId));
    return invoice.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.md),
        child: LinearProgressIndicator(),
      ),
      error: (Object error, StackTrace stack) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Text(
          'Invoice could not be loaded.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ),
      data: (CustomerInvoice? value) {
        if (!showInvoiceDownload(
          canonicalStatus: 'DELIVERED',
          invoice: value,
        )) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: SecondaryButton(
            label: _saving ? 'Preparing invoice…' : 'Download Invoice',
            enabled: !_saving,
            onPressed: () => unawaited(_download(value!)),
          ),
        );
      },
    );
  }
}
