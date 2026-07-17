class_name DefenderHurtState
extends DefenderState

var remaining := 0.0
func enter(defender: Area2D) -> void:
	defender.clear_attack_effects()
	remaining = defender.animation_duration("hurt", 0.2)
	defender.play_animation("hurt")
func process(defender: Area2D, delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0: defender.transition_to("idle")
