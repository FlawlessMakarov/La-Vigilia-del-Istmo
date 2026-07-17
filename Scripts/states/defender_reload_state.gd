class_name DefenderReloadState
extends DefenderState

var remaining := 0.0
func enter(defender: Area2D) -> void:
	remaining = defender.animation_duration("reload", 0.22)
	defender.play_animation("reload")
	if defender.reload_sound != null and defender.defender_id == "pistolero": defender.reload_sound.play()
func process(defender: Area2D, delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0: defender.transition_to("hurt" if defender.pending_hurt else "idle")
