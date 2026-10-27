// Genera los cuadros del widget de Android a partir del Lottie real de la gota.
//   flutter test tool/widget_frames_test.dart
//   cd android/app/src/main/res/drawable-nodpi && for f in heart_frame_*.png; do
//     magick "$f" -define webp:lossless=true "${f%.png}.webp" && rm "$f"; done
// (WebP sin pérdida: mismos píxeles, ~1/3 del tamaño.)
// Escribe los cuadros únicos en res/drawable-nodpi/heart_frame_XX.png (sin texto:
// el número de días lo pinta el widget encima) y regenera res/layout/days_widget.xml.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:love_app/utils/clippers.dart';

const frames = 24; // 24 cuadros cada 83 ms = el ciclo de 2 s del Lottie a 12 fps
const res = 'android/app/src/main/res';
const outerColor = Color(0xffA00FE2);
const innerColor = Color(0xFFF3ECFF);

/// Mismo dibujo que DateCounter, sin el texto.
Widget heart(AnimationController controller) => SizedBox(
      width: 283,
      height: 202,
      child: Stack(alignment: Alignment.center, children: [
        ClipPath(
          clipper: HeartClipper(),
          child: Container(width: 283, height: 202, color: outerColor),
        ),
        ClipPath(
          clipper: HeartClipper(),
          child: Container(
            width: 280,
            height: 200,
            color: innerColor,
            child: Stack(children: [
              ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: const Offset(0, -190),
                    child: SizedBox(
                      width: 283,
                      height: 300,
                      child: Lottie.asset('assets/drop_purple_water.json',
                          controller: controller, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 110,
                  decoration: const BoxDecoration(
                    color: outerColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );

void main() {
  testWidgets('cuadros del widget', (tester) async {
    final controller = AnimationController(vsync: tester, duration: const Duration(seconds: 2));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: RepaintBoundary(key: const ValueKey('h'), child: heart(controller))),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('h')));
    final dir = Directory('$res/drawable-nodpi')..createSync(recursive: true);
    final unique = <String, String>{}; // hash -> nombre del drawable
    final sequence = <String>[];
    for (var i = 0; i < frames; i++) {
      controller.value = i / frames;
      await tester.pump();
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        return png!.buffer.asUint8List();
      });
      // Los cuadros en calma son idénticos: se reutiliza un solo PNG.
      final name = unique.putIfAbsent(base64.encode(bytes!), () {
        final n = 'heart_frame_${unique.length.toString().padLeft(2, '0')}';
        File('${dir.path}/$n.png').writeAsBytesSync(bytes);
        return n;
      });
      sequence.add(name);
    }
    File('$res/layout/days_widget.xml').writeAsStringSync(layout(sequence));
    controller.dispose();
  });
}

String layout(List<String> sequence) => """<?xml version="1.0" encoding="utf-8"?>
<!-- Generado por tool/widget_frames_test.dart: no editar a mano. -->
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:contentDescription="@string/days_widget_description"
    android:padding="4dp">

    <!-- Pasa los cuadros de la gota; Android lo detiene solo con la pantalla apagada. -->
    <ViewFlipper
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:autoStart="true"
        android:flipInterval="83">
${sequence.map((n) => '        <ImageView android:layout_width="match_parent" android:layout_height="match_parent" android:scaleType="fitCenter" android:src="@drawable/$n" />').join('\n')}
    </ViewFlipper>

    <TextView
        android:id="@+id/days_text"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="center"
        android:layout_marginTop="12dp"
        android:text="@string/days_widget_placeholder"
        android:textColor="#FFFFFF"
        android:textSize="16sp"
        android:textStyle="bold" />
</FrameLayout>
""";
