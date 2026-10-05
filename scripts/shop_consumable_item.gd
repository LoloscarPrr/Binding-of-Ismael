extends "res://scripts/shop_item.gd"
class_name IsmaelShopConsumableItem

func _draw() -> void:
	var accent := Color(0.88,0.67,0.18)
	if _unaffordable:
		accent = Color(0.85,0.16,0.10)
	var shadow := Color(0.015,0.01,0.008,0.55)
	var stone := Color(0.25,0.19,0.14)
	var stone_edge := Color(0.52,0.39,0.24)
	var muted := Color(0.18,0.17,0.17)

	draw_ellipse(Vector2(0,38),Vector2(56,15),shadow)
	var base := PackedVector2Array([
		Vector2(-47,17),Vector2(47,17),Vector2(40,46),Vector2(-40,46)
	])
	draw_colored_polygon(base,stone if not sold else muted)
	draw_polyline(PackedVector2Array([
		Vector2(-47,17),Vector2(47,17),Vector2(40,46),Vector2(-40,46),Vector2(-47,17)
	]),stone_edge,3.0,true)
	var top := PackedVector2Array([
		Vector2(-52,12),Vector2(52,12),Vector2(43,23),Vector2(-43,23)
	])
	draw_colored_polygon(top,Color(0.38,0.27,0.17) if not sold else Color(0.24,0.23,0.23))
	draw_line(Vector2(-47,13),Vector2(47,13),accent,3.5)

	if sold:
		draw_line(Vector2(-24,-20),Vector2(24,12),Color(0.36,0.07,0.055),7.0)
		draw_line(Vector2(24,-20),Vector2(-24,12),Color(0.36,0.07,0.055),7.0)
		return

	# El ícono real del pickup lo añade ItemAssetView como Sprite2D hijo.
	# Aquí dejamos solamente un halo limpio para no duplicar dibujos abstractos.
	var pulse := 0.5+0.5*sin(_age*3.5)
	draw_circle(Vector2(0,-7),34.0+3.0*pulse,Color(accent,0.045+0.025*pulse))
	if _feedback > 0.0:
		draw_arc(Vector2.ZERO,56.0*(1.0-_feedback*0.18),0.0,TAU,34,Color(accent,clampf(_feedback,0.0,0.72)),5.0)
