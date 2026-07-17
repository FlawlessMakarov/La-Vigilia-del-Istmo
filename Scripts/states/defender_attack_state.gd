class_name DefenderAttackState
extends DefenderState

var remaining := 0.0
func enter(defender: Area2D) -> void:
	remaining = defender.animation_duration("attack", 0.24)
	defender.play_animation("attack")
func process(defender: Area2D, delta: float) -> void:
	remaining -= delta
	if remaining > 0.0: return
	defender.clear_attack_effects()
	if defender.pending_hurt:
		defender.pending_hurt = false
		defender.transition_to("hurt")
	elif defender.has_animation("reload") and defender.defender_id != "granjero" and defender.defender_id != "farolero": defender.transition_to("reload")
	else: defender.transition_to("idle")
