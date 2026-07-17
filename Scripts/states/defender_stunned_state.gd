class_name DefenderStunnedState
extends DefenderState

var remaining := 0.0
func enter(defender: Area2D) -> void:
	defender.clear_attack_effects()
	defender.modulate = Color(0.55, 0.67, 1.0, 1.0)
func set_duration(duration: float) -> void: remaining = max(duration, 0.05)
func process(defender: Area2D, delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0: defender.transition_to("idle")
