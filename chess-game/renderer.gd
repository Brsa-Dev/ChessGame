extends Node2D

const TILE_W = 128
const TILE_H = 64
const OFFSET = Vector2(600, 100)

func _ready():
	queue_redraw()
	print("Renderer prêt !")

func _draw():
	for x in range(8):
		for y in range(8):
			var couleur = Color.WHITE if (x + y) % 2 == 0 else Color(0.2, 0.2, 0.2)
			dessiner_case(x, y, couleur)

func dessiner_case(x: int, y: int, couleur: Color):
	var cx = OFFSET.x + (x - y) * (TILE_W / 2)
	var cy = OFFSET.y + (x + y) * (TILE_H / 2)
	var points = PackedVector2Array([
		Vector2(cx,                cy - TILE_H / 2),
		Vector2(cx + TILE_W / 2,  cy),
		Vector2(cx,                cy + TILE_H / 2),
		Vector2(cx - TILE_W / 2,  cy),
	])
	draw_colored_polygon(points, couleur)
	draw_polyline(points, Color.BLACK, 1.0)
	draw_line(points[3], points[0], Color.BLACK, 1.0)
	
func screen_to_grid(pos: Vector2) -> Vector2i:
	# On cherche quelle case contient le point cliqué
	for x in range(8):
		for y in range(8):
			if point_in_tile(pos, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)  # En dehors du plateau

# Vérifie si un point est à l'intérieur d'un losange isométrique
func point_in_tile(pos: Vector2, x: int, y: int) -> bool:
	var cx = OFFSET.x + (x - y) * (TILE_W / 2)
	var cy = OFFSET.y + (x + y) * (TILE_H / 2)
	
	# Distance relative au centre du losange
	var dx = abs(pos.x - cx)
	var dy = abs(pos.y - cy)
	
	# Formule exacte pour un losange isométrique
	return (dx / (TILE_W / 2.0) + dy / (TILE_H / 2.0)) <= 1.0
