extends Node2D

const TILE_W = 128
const TILE_H = 64
const OFFSET = Vector2(600, 100)

# Référence au Board, assignée par main.gd au démarrage
var board: Node = null

# Référence au joueur, assignée par main.gd au démarrage
var joueur: Node = null

# Couleurs par type de case
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
	# 1. On dessine le plateau
	for x in range(8):
		for y in range(8):
			var type = board.get_case(x, y) if board != null else 0
			var couleur = COULEURS.get(type, Color.WHITE)
			dessiner_case(x, y, couleur)
	
	# 2. On vérifie que le joueur existe ET qu'il a bien la propriété est_place
	# avant de tenter d'y accéder
	if joueur != null and joueur.get("est_place") == true:
		dessiner_joueur(joueur.grid_x, joueur.grid_y)

func dessiner_case(x: int, y: int, couleur: Color):
	var cx = OFFSET.x + (x - y) * (TILE_W / 2)
	var cy = OFFSET.y + (x + y) * (TILE_H / 2)
	var points = PackedVector2Array([
		Vector2(cx,               cy - TILE_H / 2),
		Vector2(cx + TILE_W / 2, cy),
		Vector2(cx,               cy + TILE_H / 2),
		Vector2(cx - TILE_W / 2, cy),
	])
	draw_colored_polygon(points, couleur)
	draw_polyline(points, Color.BLACK, 1.0)
	draw_line(points[3], points[0], Color.BLACK, 1.0)

# Dessine un cercle au centre de la case (x, y)
# Ce cercle sera remplacé par un sprite ou modèle 3D plus tard
func dessiner_joueur(x: int, y: int):
	var cx = OFFSET.x + (x - y) * (TILE_W / 2)
	var cy = OFFSET.y + (x + y) * (TILE_H / 2)
	draw_circle(Vector2(cx, cy), 20, Color.YELLOW)

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
