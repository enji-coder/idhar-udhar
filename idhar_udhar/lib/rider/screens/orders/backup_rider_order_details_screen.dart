const SizedBox(height: RiderSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: RiderColors.secondary,
                                content: Text(
                                  'Masked calling (demo)',
                                  style: RiderTextStyles.bodyMedium.copyWith(
                                    color: RiderColors.textOnPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.call_rounded),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RiderColors.primary,
                            side: const BorderSide(color: RiderColors.primary),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: RiderSpacing.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(RiderRoutes.activeDelivery),
                          icon: const Icon(Icons.navigation_rounded),
                          label: const Text('Navigate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RiderColors.primary,
                            side: const BorderSide(color: RiderColors.primary),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                    ],
                  ),