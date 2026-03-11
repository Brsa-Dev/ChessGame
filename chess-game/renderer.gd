extends Node2D

# Taille d'une case isométrique (même valeur que dans ton TileSet)
const TILE_W = 128
const TILE_H = 64

# Décalage pour centrer la grille à l'écran
const OFFSET = Vector2(600, 100)

func _ready():
	queue_redraw()

func _draw():
	for x in range(8):
		for y in range(8):
			# Alterne la couleur selon (x + y) pair ou impair
			var couleur = Color.WHITE if (x + y) % 2 == 0 else Color(0.2, 0.2, 0.2)
			dessiner_case(x, y, couleur)

# Dessine un losange isométrique à la position (x, y) de la grille
func dessiner_case(x: int, y: int, couleur: Color):
	var cx = OFFSET.x + (x - y) * (TILE_W / 2)
	var cy = OFFSET.y + (x + y) * (TILE_H / 2)
	
	var points = PackedVector2Array([
		Vector2(cx,              cy - TILE_H / 2),  # Haut
		Vector2(cx + TILE_W / 2, cy),               # Droite
		Vector2(cx,              cy + TILE_H / 2),  # Bas
		Vector2(cx - TILE_W / 2, cy),               # Gauche
	])
	
	draw_colored_polygon(points, couleur)
	draw_polyline(points, Color.BLACK, 1.0)
	# Ferme le contour entre le dernier et le premier point
	draw_line(points[3], points[0], Color.BLACK, 1.0)
