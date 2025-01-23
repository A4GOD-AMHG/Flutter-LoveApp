import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  void _showDedicationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: AlertDialog(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(
                        'Feliz Día',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                content: Text(
                  '  Y si, simplemente feliz día, porque cada día cualquiera de estos es especial a su forma, eso me enseñaste tú.\n'
                  '  Pos esta aplicación está dedicada a la persona más hermosa del mundo, se llama Anyel Emilia Moya Ruiz por si no sabes, no es muy complejo esto, pero al menos cuenta los días que llevamos.\n'
                  '  Ahora que me pongo a pensar, tal vez cuando llevemos muchos añitos el número no encaje en el corazón haha, pero bueno, ya lo arreglaré en su momento.\n'
                  '  Disfruta cada día, así como yo disfruto cualquier oportunidad amarte o sorprenderte con algo. \n¡TE AMO!',
                  style: TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    child: Text('Cerrar'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: SizedBox(
        height: 50,
        child: Row(
          spacing: 40,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Text(
                'Contador de Amor',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1.5),
                borderRadius: BorderRadius.circular(100),
              ),
              child: IconButton(
                onPressed: () => _showDedicationDialog(context),
                icon: Icon(Icons.question_mark_outlined, color: Colors.white),
                iconSize: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
