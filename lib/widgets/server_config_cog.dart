import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../utils/theme_controller.dart';

class ServerConfigCog extends StatelessWidget {
  const ServerConfigCog({
    super.key,
    this.iconColor,
    this.iconSize = 24,
    this.onSaved,
  });

  final Color? iconColor;
  final double iconSize;
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ??
        (ThemeProvider.of(context).isDark ? Colors.white70 : Colors.black54);

    return IconButton(
      tooltip: 'Configurar servidor',
      icon: Icon(Icons.settings, color: resolvedIconColor, size: iconSize),
      onPressed: () => _showServerConfigDialog(context),
    );
  }

  Future<void> _showServerConfigDialog(BuildContext context) async {
    final storage = StorageService();
    final currentHost = await storage.getServerHost();
    final currentWs = await storage.getWsUrl();

    if (!context.mounted) return;

    final hostController = TextEditingController(text: currentHost);
    final wsController = TextEditingController(text: currentWs);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final themeController = ThemeProvider.of(dialogContext);
        final isDark = themeController.isDark;
        final textColor = isDark ? Colors.white : Colors.black;
        final cardColor = isDark ? const Color(0xFF2d2640) : Colors.white;

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Configurar servidor',
            style: TextStyle(color: textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hostController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Host API (http/https)',
                    labelStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                    ),
                    hintText: StorageService.defaultHost,
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: textColor.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: textColor),
                    ),
                    prefixIcon: Icon(
                      Icons.public,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: wsController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'WebSocket (ws/wss)',
                    labelStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                    ),
                    hintText: StorageService.defaultWsUrl,
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: textColor.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: textColor),
                    ),
                    prefixIcon: Icon(
                      Icons.wifi,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      hostController.text = StorageService.defaultHost;
                      wsController.text = StorageService.defaultWsUrl;
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Usar valores por defecto'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancelar', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () {
                final host = _normalizeUrl(hostController.text);
                final wsInput = wsController.text.trim();
                final derivedWs = _deriveWsFromHost(host);
                final ws = wsInput.isEmpty ? derivedWs : _normalizeUrl(wsInput);

                final hostUri = Uri.tryParse(host);
                final wsUri = Uri.tryParse(ws);

                final validHost = hostUri != null &&
                    (hostUri.scheme == 'http' || hostUri.scheme == 'https') &&
                    hostUri.host.isNotEmpty;
                final validWs = wsUri != null &&
                    (wsUri.scheme == 'ws' || wsUri.scheme == 'wss') &&
                    wsUri.host.isNotEmpty;

                if (!validHost) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Host inválido. Usa http:// o https://',
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (!validWs) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('WebSocket inválido. Usa ws:// o wss://',
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B59B6),
              ),
              child:
                  const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (saved != true || !context.mounted) return;

    final host = _normalizeUrl(hostController.text);
    final ws = _normalizeUrl(wsController.text);

    await storage.saveServerHost(host);
    await storage.saveWsUrl(ws);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Servidor actualizado correctamente',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
    );

    onSaved?.call();
  }

  String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _deriveWsFromHost(String host) {
    final uri = Uri.tryParse(host);
    if (uri == null || uri.host.isEmpty) {
      return StorageService.defaultWsUrl;
    }

    var scheme = uri.scheme.toLowerCase();
    if (scheme == 'http') {
      scheme = 'ws';
    } else if (scheme == 'https') {
      scheme = 'wss';
    } else if (scheme != 'ws' && scheme != 'wss') {
      scheme = 'wss';
    }

    return uri.replace(scheme: scheme).toString();
  }
}
