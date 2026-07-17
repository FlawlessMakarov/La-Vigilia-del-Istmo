# La Vigilia del Istmo

Juego de defensa por carriles desarrollado con Godot 4.6.

## Abrir el proyecto

1. Instala Godot 4.6 o una versión compatible.
2. Importa el archivo `project.godot` desde el administrador de proyectos de Godot.
3. Ejecuta la escena principal desde el editor.

## Contenido

- Escenas, scripts y recursos del juego.
- Sprites, mapas y audio necesarios para ejecutarlo.
- La carpeta `.godot/` no se incluye porque Godot la regenera automáticamente.

## Estructura del código

- `Assets/`: audio, sprites, mapa y recursos visuales del menú.
- `Scenes/`: pantallas y unidades del juego.
- `Scripts/`: código separado por responsabilidad.

```
Assets/
  Audio/       Sonidos y música
  Maps/        Mapa de batalla
  Menu/        Fondo, título y niebla del menú
  Sprites/     Animaciones de defensores y enemigos
Scenes/
  Game/        Escena principal de la partida
  Menu/        Escena del menú
  Defenders/   Escenas de torres
  Enemies/     Escenas de monstruos
Scripts/
  core/        Configuración y tablero
  gameplay/    Catálogos de juego
  states/      Estados de defensores y enemigos
  ui/          Interfaz de cartas
```

Para ajustar costos, tiempos, filas o columnas, usa `Scripts/core/game_config.gd`.
