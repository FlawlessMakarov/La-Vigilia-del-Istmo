class_name EnemyHurtState
extends EnemyState

var remaining := 0.0

func enter(enemy: Node2D) -> void:
	enemy.is_blocked = true
	enemy.set_sprite_scale(1.0)
	enemy.attack_timer.stop()
	remaining = enemy.animation_duration("hurt", 0.18)
	enemy.play_animation("hurt", "walk")

func process(enemy: Node2D, delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		enemy.transition_to("attack" if enemy.find_defender_in_range() != null else "walk")
