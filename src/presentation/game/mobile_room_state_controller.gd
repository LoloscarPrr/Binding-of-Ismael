extends "res://src/presentation/game/mobile_controls_editor_controller.gd"

# Presentation-only refinement for revisiting rooms. Completed combat rooms keep
# their completed state in the HUD instead of showing PREPÁRATE again.

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	super._begin_room(entry_direction)
	_refresh_completed_room_status()

func _refresh_completed_room_status() -> void:
	if not _room_cleared or not is_instance_valid(status_label):
		return
	match _room_kind:
		"combate":
			status_label.text = "SALA LIMPIA"
		"emboscada":
			status_label.text = "EMBOSCADA SUPERADA"
		"desafio":
			status_label.text = "DESAFÍO SUPERADO"
		"minijefe":
			status_label.text = "GUARDIÁN MENOR DERROTADO"
		"jefe":
			status_label.text = "GUARDIÁN DERROTADO — ENCUENTRA LA SALIDA"
