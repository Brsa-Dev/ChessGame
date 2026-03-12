extends Node2D

const TILE_W = 128
const TILE_H = 64
const OFFSET = Vector2(600, 100)

# Référence au Board, assignée par main.gd au démarrage
var board: Node = null

# Couleurs par type de case
# Les clés correspondent aux valeurs de l'enum CaseType dans board.gd :
# 0 = NORMAL, 1 = LAVE, 2 = EAU, 3 = VIDE, 4 = FORET, 5 = MUR, 6 = TOUR
const COULEURS = {
	0: Color(0.85, 0.85, 0.85),  # NORMAL  — gris clair
	1: Color(0.9,  0.3,  0.1 ),  # LAVE    — rouge/orange
	2: Color(0.2,  0.5,  0.9 ),  # EAU     — bleu
	3: Color(0.1,  0.1,  0.1 ),  # VIDE    — noir
	4: Color(0.1,  0.6,  0.1 ),  # FORET   — vert
	5: Color(0.5,  0.4,  0.3 ),  # MUR     — marron
	6: Color(0.7,  0.6,  0.1 ),  # TOUR    — doré
}

func _ready():
	print("Renderer prêt !")

func _draw():
	for x in range(8):
		for y in range(8):
			# Si le board est connecté, on lit le vrai type de la case
			# Sinon, on affiche tout en gris clair par défaut
			var type = board.get_case(x, y) if board != null else 0
			var couleur = COULEURS.get(type, Color.WHITE)
			dessiner_case(x, y, couleur)

func dessiner_case(x: int, y: int, couleur: Color):
	var cx = OFFSET.x + (x - y) * (TILE_W / 2)
	var cy = OFFSET.y + (x + y) * (TILE_H / 2)
	var points = PackedVector2Array([
		Vector2(cx,cy - TILE_H / 2),
		Vector2(cx + TILE_W / 2,  cy),
		Vector2(cx,cy + TILE_H / 2),
		Vector2(cx - TILE_W / 2,  cy),
	])
	draw_colored_polygon(points, couleur)
	draw_polyline(points, Color.BLACK, 1.0)
	draw_line(points[3], points[0], Color.BLACK, 1.0)

func screen_to_grid(pos: Vector2) -> Vector2i:
	for x in range(8):
		for y in range(8):
			if point_in_tile(pos, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func point_in_tile(pos: Vector2, x: int, y: int) -> bool:
	var cx = OFFSET.x + (x - y) * (TILE_W / 2)
	var cy = OFFSET.y + (x + y) * (TILE_H / 2)
	var dx = abs(pos.x - cx)
	var dy = abs(pos.y - cy)
	return (dx / (TILE_W / 2.0) + dy / (TILE_H / 2.0)) <= 1.0
