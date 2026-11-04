import 'package:flutter/material.dart';

import '../../services/log_sharing.dart';
import '../strings.dart';

/// What stands in place of a widget that failed to build: a plain note and a
/// way to save the journal, instead of the red (or grey) error screen.
/// It must not lean on anything that may be missing, so it has its own colors.
class BrokenWidget extends StatelessWidget {
  const BrokenWidget({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFF263238),
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(S.somethingWrong,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none)),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: S.saveLog,
                  child: GestureDetector(
                    onTap: () => shareLog().catchError((Object _) {}),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.centerLeft,
                      child: const Text(S.saveLog,
                          style: TextStyle(
                              color: Color(0xFF80CBC4),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
