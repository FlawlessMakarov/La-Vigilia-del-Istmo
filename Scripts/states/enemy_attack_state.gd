class_name EnemyAttackState
extends EnemyState
func enter(enemy: Node2D) -> void:
	enemy.is_blocked = true; enemy.set_sprite_scale(enemy.attack_visual_scale); enemy.play_animation("attack", "walk"); enemy.deal_damage_to_defender(); enemy.attack_timer.start()
func process(enemy: Node2D, _delta: float) -> void:
	enemy.current_defender = enemy.find_defender_in_range()
	if enemy.current_defender == null: enemy.transition_to("walk")
func on_attack_timer(enemy: Node2D) -> void:
	if enemy.current_defender == null or not enemy.is_defender_in_range(enemy.current_defender): enemy.transition_to("walk")
	else: enemy.deal_damage_to_defender()
