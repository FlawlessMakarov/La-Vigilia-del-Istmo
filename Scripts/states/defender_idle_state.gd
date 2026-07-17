class_name DefenderIdleState
extends DefenderState

func enter(defender: Area2D) -> void:
	defender.modulate = Color.WHITE
	defender.play_animation("idle")

func process(defender: Area2D, delta: float) -> void:
	if defender.defender_id == "farolero": defender.process_farolero(delta)
	else: defender.process_attacker()
