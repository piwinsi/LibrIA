# LibrIA

Aplicación móvil para el **registro, seguimiento y socialización de la actividad lectora**, desarrollada en Flutter como parte de un trabajo de tesis.

LibrIA permite al lector armar su biblioteca personal, registrar su avance, dejar valoraciones y reseñas, revisar estadísticas de su trayectoria y recibir recomendaciones de lectura basadas en sus gustos y en lo que realmente lee.

## Funcionalidades

| Requisito | Descripción |
|-----------|-------------|
| RF-01 | Cuentas locales de usuario (registro e inicio de sesión). |
| RF-02 | Perfil lector editable, con géneros favoritos elegidos en el onboarding. |
| RF-03 | Biblioteca personal: agregar libros por búsqueda (título/autor), escaneo del código de barras ISBN o formulario manual, con portada desde la galería o la cámara. |
| RF-04 | Estados de lectura: pendiente, leyendo, en pausa, terminado y abandonado. |
| RF-05 | Registro del avance (páginas) y de las fechas de inicio y término. |
| RF-06 | Valoración, reseña y comentarios personales por libro. |
| RF-07 | Estadísticas e historial de la trayectoria lectora, con gráficos. |
| RF-08 | Recomendaciones compartidas con otras apps. |
| RNF-03 | Privacidad: el perfil es privado por defecto. |
| RNF-04 | Contraseñas almacenadas con hash, nunca en texto plano. |
| RNF-05 | Presentación visual consistente de los estados de lectura. |
| RNF-07 | Persistencia local de biblioteca, perfil y actividad en el dispositivo. |

Además, la sección **Descubrir** ofrece sugerencias de lectura generadas por un motor de recomendación que combina los géneros del onboarding con los géneros y autores de la biblioteca del usuario; a medida que se registra actividad, las sugerencias se apoyan cada vez más en las lecturas reales. Cada sugerencia indica el motivo por el que se propone.

## Fuentes de datos

Los datos bibliográficos se obtienen de catálogos públicos que no requieren clave de API:

- **Google Books** (fuente principal).
- **Open Library** (respaldo).
- **Inventaire.io** (respaldo para ediciones en español y europeas en la búsqueda por ISBN).

Si no hay conexión, la aplicación sigue funcionando con su catálogo local ([lib/data/local_catalog.dart](lib/data/local_catalog.dart)).

## Cuenta de demostración

Desde la pantalla de bienvenida se puede entrar con una cuenta de demostración que trae una biblioteca de ejemplo (libros en los cinco estados, avance, valoraciones, reseñas y una recomendación compartida):

- Correo: `demo@libria.cl`
- Contraseña: `libria123`

## Tecnologías

- [Flutter](https://flutter.dev/) (Dart SDK ^3.12.2)
- `provider` para la gestión de estado
- `shared_preferences` para la persistencia local
- `http` para las consultas a los catálogos
- `fl_chart` para los gráficos de estadísticas
- `mobile_scanner` para el escáner de ISBN
- `image_picker`, `share_plus`, `crypto` y `flutter_svg`

## Estructura del proyecto

```
lib/
├── main.dart                   # Arranque: servicios, providers y sesión guardada
├── main_navigation_screen.dart # Navegación inferior (Inicio, Biblioteca, Descubrir, Estadísticas, Perfil)
├── app/                        # Widget raíz y tema
├── core/                       # Géneros y utilidades
├── data/                       # Catálogo local y datos de la cuenta demo
├── models/                     # Libro, usuario, eventos de lectura, comentarios, recomendaciones
├── providers/                  # Estado: autenticación, biblioteca y recomendaciones
├── services/                   # Almacenamiento local, búsqueda de libros, hash y motor de recomendación
├── widgets/                    # Componentes reutilizables
└── features/                   # Pantallas por módulo
    ├── auth/                   # Bienvenida, inicio de sesión y registro
    ├── onboarding/             # Selección de géneros favoritos
    ├── home/                   # Inicio
    ├── library/                # Biblioteca, ficha del libro, avance, búsqueda y escáner ISBN
    ├── discover/               # Recomendaciones y catálogo
    ├── statistics/             # Estadísticas e historial
    └── profile/                # Perfil, edición y recomendaciones compartidas
```

## Ejecución

Requisitos: Flutter SDK instalado y un dispositivo o emulador (Android, iOS, web o Windows).

```bash
flutter pub get
flutter run
```

> El escáner de ISBN usa la cámara y está disponible en Android, iOS, macOS y web. En Windows los libros se agregan por búsqueda o de forma manual.

## Pruebas

```bash
flutter test
```

Las pruebas están en [test/](test/): `logic_test.dart` cubre utilidades (ISBN, géneros, hash), el motor de recomendaciones y el flujo de la biblioteca, y `widget_test.dart` los flujos de bienvenida, registro con onboarding y la cuenta demo.
