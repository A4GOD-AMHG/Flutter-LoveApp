import 'package:love_app/utils/theme_controller.dart';
import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  void _showDedicationDialog(BuildContext context) {
    final themeController = ThemeProvider.of(context);
    final isDark = themeController.isDark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 350),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  padding: EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Feliz Día',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                color: isDark ? Colors.white : Colors.black),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '  Y si, simplemente feliz día, porque cada día es especial a su forma, eso me enseñaste tú.\n'
                          '  Pos esta aplicación está dedicada a la persona más hermosa del mundo, se llama Anyel Emilia Moya Ruiz por si no sabías, la hice para que cuente los días que llevamos, pero eventualmente la hare crecer, quiero que me recuerdes cuando la veas en tu móvil y la abras cuando me extrañes, soy muy egoísta y no me alcanza con llenarte un mueble de recuerdos, también te llenare el celular buahahaha.\n'
                          '  Y áun sigo pensando, tal vez cuando llevemos muchos añitos el número no encaje en el corazón, pero bueno, ya lo arreglaré en su momento.\n'
                          '  Disfruta cada día, así como yo disfruto cualquier oportunidad amarte o sorprenderte con algo. \n¡TE AMO!',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: Text('Cerrar'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeProvider.of(context);
    final isDark = themeController.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF0C0522) : Color.fromARGB(255, 255, 255, 255),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
        child: SizedBox(
          height: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Alexis x Anyel',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.deepPurple,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Row(
                children: [
                  Switch(
                    value: isDark,
                    onChanged: (_) => themeController.toggle(),
                    activeColor: Color(0xFF000000),
                    activeTrackColor: const Color(0xFF7E7A83),
                    inactiveThumbColor: Colors.amber.shade700,
                    inactiveTrackColor: Colors.amber.shade100,
                    thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Icon(
                          Icons.nightlight_round,
                          color: Colors.white,
                          size: 16,
                        );
                      } else {
                        return Icon(
                          Icons.wb_sunny_rounded,
                          color: Colors.white,
                          size: 16,
                        );
                      }
                    }),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            isDark ? Colors.deepPurple.shade300 : Colors.black,
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: IconButton(
                      hoverColor: Colors.transparent,
                      onPressed: () => _showDedicationDialog(context),
                      icon: Icon(
                        Icons.question_mark_outlined,
                        color:
                            isDark ? Colors.white : Colors.deepPurple.shade700,
                      ),
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
