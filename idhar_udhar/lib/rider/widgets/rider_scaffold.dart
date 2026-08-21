import 'package:flutter/material.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import 'rider_background.dart';

/// Shared Rider page shell — background + SafeArea + responsive padding.
class RiderScaffold extends StatelessWidget {
  const RiderScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.bottom,
    this.padding,
    this.resizeToAvoidBottomInset = true,
    this.floatingActionButton,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottom;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final Widget? bottomBar = bottom;
    // When resizeToAvoidBottomInset is true, Scaffold already shrinks for the
    // keyboard — do not add viewInsets again (that hid OTP fields).
    final double keyboardInset = resizeToAvoidBottomInset
        ? 0
        : MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: RiderColors.background,
      extendBodyBehindAppBar: false,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: RiderBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: padding ??
                      EdgeInsets.fromLTRB(
                        RiderSpacing.screenH,
                        RiderSpacing.lg,
                        RiderSpacing.screenH,
                        bottomBar == null
                            ? RiderSpacing.lg + keyboardInset
                            : RiderSpacing.sm,
                      ),
                  child: body,
                ),
              ),
              if (bottomBar != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    RiderSpacing.screenH,
                    RiderSpacing.sm,
                    RiderSpacing.screenH,
                    RiderSpacing.lg + keyboardInset,
                  ),
                  child: bottomBar,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
