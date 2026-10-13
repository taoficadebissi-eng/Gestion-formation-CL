import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOnline;

  const OfflineBanner({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        height: isOnline ? 0 : 40,
        child: isOnline
            ? null
            : Container(
                width: double.infinity,
                color: Colors.red.shade700,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Vous etes hors ligne',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
