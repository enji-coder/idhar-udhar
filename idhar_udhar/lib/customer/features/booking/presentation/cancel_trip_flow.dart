import 'package:flutter/material.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/shared/widgets/custom_dialog.dart';

Future<bool> confirmCustomerCancellation({
  required BuildContext context,
  required MockOrder order,
}) async {
  final quote = order.cancellationQuote;
  if (!quote.allowed) {
    await CustomDialog.show(
      context: context,
      title: 'Cancel Trip',
      message: quote.message,
      confirmLabel: 'OK',
      cancelLabel: null,
    );
    return false;
  }
  final bool? ok = await CustomDialog.show(
    context: context,
    title: 'Cancel Trip',
    message: quote.message,
    confirmLabel: 'Cancel Trip',
    cancelLabel: 'Keep Trip',
  );
  return ok == true;
}
