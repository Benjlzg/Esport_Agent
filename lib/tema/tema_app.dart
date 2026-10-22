// Colores y estilos de toda la app. Estilo oscuro tipo "gamer".
import 'package:flutter/material.dart';

/// Espacio libre que se deja al final de las listas para que el botón
/// flotante "Avanzar semana" no tape el último elemento.
const double margenBotonAvanzarSemana = 100;

/// Paleta de colores de la app. Cámbialos aquí y cambia toda la app.
class AppColores {
  AppColores._(); // No se puede crear un objeto de esta clase.

  static const Color fondo = Color(0xFF0D0F14);
  static const Color superficie = Color(0xFF171A21);
  static const Color acento = Color(0xFF7C4DFF); // violeta
  static const Color acento2 = Color(0xFF00E5FF); // celeste neón
  static const Color exito = Color(0xFF00C853);
  static const Color peligro = Color(0xFFFF5252);
  static const Color dorado = Color(0xFFFFD54F);
  static const Color textoPrincipal = Color(0xFFFFFFFF);
  static const Color textoSecundario = Color(0xFF9AA0A6);
}

/// Crea el tema oscuro que usa toda la app.
class TemaApp {
  TemaApp._();

  static ThemeData obtenerTema() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColores.acento,
        secondary: AppColores.acento2,
        surface: AppColores.superficie,
        error: AppColores.peligro,
      ),
      scaffoldBackgroundColor: AppColores.fondo,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColores.fondo,
        foregroundColor: AppColores.textoPrincipal,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: AppColores.superficie,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.acento,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColores.superficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColores.superficie,
        indicatorColor: AppColores.acento,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, color: AppColores.textoPrincipal),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: AppColores.textoPrincipal),
        ),
      ),
      dividerColor: Colors.white12,
    );
  }
}
