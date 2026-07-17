class_name EnemyWalkState
extends EnemyState

func enter(enemy: Node2D) -> void:
	enemy.is_blocked = false
	enemy.set_sprite_scale(1.0)
	enemy.attack_timer.stop()
	enemy.play_animation("walk")

func process(enemy: Node2D, delta: float) -> void:
	var defender := enemy.find_defender_in_range()
	enemy.current_defender = defender
	if defender != null:
		enemy.transition_to("attack")
		return
	enemy.position.x -= enemy.speed * delta
