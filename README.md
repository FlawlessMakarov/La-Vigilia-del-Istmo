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

- `game.gd`: controlador de la partida; coordina recursos, colocación y finales.
- `enemy_spawner.gd`: crea enemigos y controla el ritmo de aparición.
- `Scripts/core/`: configuración central y reglas del tablero.
- `Scripts/gameplay/`: catálogos y lógica compartida de juego.
- `Scripts/ui/`: componentes de interfaz reutilizables.
- `Scripts/base_defender.gd` y `Scripts/base_enemy.gd`: comportamiento de cada unidad.

Para ajustar costos, tiempos, filas o columnas, usa `Scripts/core/game_config.gd`.
