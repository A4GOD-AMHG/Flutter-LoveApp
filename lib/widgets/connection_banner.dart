import 'package:flutter/material.dart';

enum AuthBannerState { hidden, online, sessionExpired }

/// Banner superior compartido por Tareas y Mensajes.
class ConnectionBanner extends StatelessWidget {
  final AuthBannerState state;

  const ConnectionBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (state) {
      AuthBannerState.hidden => (null, null, null),
      AuthBannerState.online => (
          Colors.green[700],
          Icons.check_circle,
          'Conexión restablecida',
        ),
      AuthBannerState.sessionExpired => (
          Colors.red[700],
          Icons.warning_amber_rounded,
          'Sesión expirada. Cierra sesión y vuelve a iniciar.',
        ),
    };
    if (text == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
