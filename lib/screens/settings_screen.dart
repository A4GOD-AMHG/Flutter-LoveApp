import '../services/storage_service.dart';
import '../utils/theme_controller.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/push_token_service.dart';
import '../services/app_state_service.dart';
import '../widgets/header.dart';
import '../widgets/server_config_cog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();
  final DatabaseService _db = DatabaseService();
  String? _username;
  bool _isUserLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _storage.getUser();
    setState(() {
      _username = user?.username;
      _isUserLoaded = true;
    });
  }

  Future<void> _changePassword() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeController = ThemeProvider.of(context);
        final isDark = themeController.isDark;
        final textColor = isDark ? Colors.white : Colors.black;
        final cardColor = isDark ? const Color(0xFF2d2640) : Colors.white;

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text('Cambiar Contraseña', style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Nueva Contraseña',
                  labelStyle:
                      TextStyle(color: textColor.withValues(alpha: 0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: textColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                  prefixIcon: Icon(Icons.lock_outline,
                      color: textColor.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Confirmar Contraseña',
                  labelStyle:
                      TextStyle(color: textColor.withValues(alpha: 0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: textColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                  prefixIcon: Icon(Icons.lock_outline,
                      color: textColor.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () {
                if (newPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa una contraseña',
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Las contraseñas no coinciden',
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B59B6),
              ),
              child: const Text(
                'Cambiar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (result == true && newPasswordController.text.isNotEmpty) {
      try {
        final changedOnline =
            await _apiService.changePassword(newPasswordController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  changedOnline
                      ? '¡Contraseña actualizada con éxito! ✨'
                      : 'Contraseña actualizada localmente. Se sincronizará al volver la conexión.',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: changedOnline ? Colors.green : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cambiar contraseña: $e',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeController = ThemeProvider.of(context);
        final isDark = themeController.isDark;
        final textColor = isDark ? Colors.white : Colors.black;
        final cardColor = isDark ? const Color(0xFF2d2640) : Colors.white;

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text('Cerrar Sesión', style: TextStyle(color: textColor)),
          content: Text(
            '¿Estás seguro de que quieres cerrar sesión?',
            style: TextStyle(color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await PushTokenService.instance.unregisterTokenFromBackend();
        await _apiService.logout();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesión: $e',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearLocalData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeController = ThemeProvider.of(context);
        final isDark = themeController.isDark;
        final textColor = isDark ? Colors.white : Colors.black;
        final cardColor = isDark ? const Color(0xFF2d2640) : Colors.white;

        return AlertDialog(
          backgroundColor: cardColor,
          title:
              Text('Vaciar datos locales', style: TextStyle(color: textColor)),
          content: Text(
            'Esto borrará mensajes, tareas, caché y cola local sin cerrar sesión. ¿Continuar?',
            style: TextStyle(color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Vaciar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _db.clearAllLocalData();
      AppStateService.instance.notifyLocalDataCleared();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos locales eliminados'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error vaciando datos locales: $e',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeProvider.of(context);
    final isDark = themeController.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2d2640) : Colors.white;

    return Stack(
      children: [
        Column(
          children: [
            const Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isUserLoaded)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _username == 'anyel'
                                  ? const Color(0xFF90EE90)
                                      .withValues(alpha: 0.3)
                                  : const Color(0xFFFFD700)
                                      .withValues(alpha: 0.3),
                              border: Border.all(
                                color: _username == 'anyel'
                                    ? const Color(0xFF90EE90)
                                    : const Color(0xFFFFD700),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  _username == 'anyel'
                                      ? 'assets/frog.png'
                                      : 'assets/duck.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: SizedBox(
                        width: 110,
                        height: 110,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Cuenta',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingTile(
                    icon: Icons.lock_outline,
                    title: 'Cambiar Contraseña',
                    subtitle: 'Actualiza tu contraseña de acceso',
                    onTap: _changePassword,
                    textColor: textColor,
                    cardColor: cardColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sesión',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingTile(
                    icon: Icons.logout,
                    title: 'Cerrar Sesión',
                    subtitle: 'Sal de tu cuenta',
                    onTap: _logout,
                    textColor: textColor,
                    cardColor: cardColor,
                    iconColor: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildSettingTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Vaciar Datos Locales',
                    subtitle: 'Borra datos y locales en este dispositivo',
                    onTap: _clearLocalData,
                    textColor: textColor,
                    cardColor: cardColor,
                    iconColor: Colors.deepOrange,
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 72,
          right: 12,
          child: ServerConfigCog(
            iconColor: textColor.withValues(alpha: 0.7),
            onSaved: () => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textColor,
    required Color cardColor,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: BoxBorder.all(color: Colors.white38)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (iconColor ?? textColor).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? textColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: textColor.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
