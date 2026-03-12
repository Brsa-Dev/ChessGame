extends Node2D

const TILE_W = 128
const TILE_H = 64
const OFFSET = Vector2(600, 100)

var board: Node = null
var joueurs: Array = []
var joueur_actif: Node = null
var joueur_selectionne: bool = false

const COULEURS = {
	0: Color(0.85, 0.85, 0.85),  # NORMAL  — gris clair
	1: Color(0.9,  0.3,  0.1 ),  # LAVE    — rouge/orange
	2: Color(0.2,  0.5,  0.9 ),  # EAU     — bleu
	3: Color(0.1,  0.1,  0.1 ),  # VIDE    — noir
	4: Color(0.1,  0.6,  0.1 ),  # FORET   — vert
	5: Color(0.5,  0.4,  0.3 ),  # MUR     — marron
	6: Color(0.7,  0.6,  0.1 ),  # TOUR    — doré
}

const COULEURS_JOUEURS = [
	Color.YELLOW,  # Joueur 1 — jaune
	Color.BLUE,    # Joueur 2 — bleu
	Color.GREEN,    # Joueur 3 ← ajouté
]

# En haut avec les autres constantes de couleur
const COULEUR_SORT = Color(0.7, 0.2, 1.0, 0.5)  # Violet transparent

# Ajoute cette variable
var sort_selectionne: int = -1  # Index du sort actif (-1 = aucun)

# Surbrillance déplacement — jaune transparent
const COULEUR_ACCESSIBLE = Color(1.0, 1.0, 0.3, 0.5)
# Surbrillance attaque — rouge transparent
const COULEUR_ATTAQUE = Color(1.0, 0.2, 0.2, 0.5)

func _ready():
	print("Renderer prêt !")

func _draw():
	# 1. On dessine le plateau
	for x in range(8):
		for y in range(8):
			var type = board.get_case(x, y) if board != null else 0
			var couleur = COULEURS.get(type, Color.WHITE)
			dessiner_case(x, y, couleur)

	if joueurs.is_empty():
		return

	# 2. Si le joueur est sélectionné, on affiche les deux surbrillances
	if joueur_actif != null and joueur_selectionne:
		_dessiner_cases_accessibles()
		_dessiner_cases_attaquables()
		# Surbrillance du sort — vérifie que l'index est valide
		if sort_selectionne >= 0 and sort_selectionne < joueur_actif.sorts.size():
			_dessiner_cases_sort()

	# 3. On dessine tous les joueurs placés
	for i in range(joueurs.size()):
		var joueur = joueurs[i]
		# On ignore les joueurs morts ou non placés
		if joueur != null and joueur.est_place and not joueur.est_mort:
			var couleur = COULEURS_JOUEURS[i]
			var rayon = 22 if joueur == joueur_actif else 16
			dessiner_joueur(joueur.grid_x, joueur.grid_y, couleur, rayon)
# Cases de déplacement — jaune, cases libres uniquement
func _dessiner_cases_accessibles():
	for x in range(8):
		for y in range(8):
			if x == joueur_actif.grid_x and y == joueur_actif.grid_y:
				continue
			
			# On n'affiche pas de surbrillance sur VIDE et MUR
			var type_case = board.get_case(x, y)
			if type_case == board.CaseType.VIDE or type_case == board.CaseType.MUR:
				continue
			
			var occupee = false
			for joueur in joueurs:
				if joueur.est_place and joueur != joueur_actif:
					if joueur.grid_x == x and joueur.grid_y == y:
						occupee = true
						break
			if occupee:
				continue
			if joueur_actif.peut_se_deplacer_vers(x, y):
				_dessiner_surbrillance(x, y, COULEUR_ACCESSIBLE)

# Cases d'attaque — rouge, uniquement sur les ennemis à portée
func _dessiner_cases_attaquables():
	for joueur in joueurs:
		if joueur == joueur_actif:
			continue
		if joueur.est_place and not joueur.est_mort:
			# peut_attaquer() gère tous les cas :
			# - attaque normale
			# - 2ème attaque du Fripon
			if joueur_actif.peut_attaquer(joueur.grid_x, joueur.grid_y):
				_dessiner_surbrillance(joueur.grid_x, joueur.grid_y, COULEUR_ATTAQUE)

func _dessiner_cases_sort():
	var sort = joueur_actif.sorts[sort_selectionne]
	
	# La Flèche Rebondissante utilise la portée RÉELLE du joueur
	# (inclut le +1 du passif Archer en forêt)
	var portee_effective = joueur_actif.attaque_portee if sort.id == "archer_fleche" else sort.portee
	
	for x in range(8):
		for y in range(8):
			if x == joueur_actif.grid_x and y == joueur_actif.grid_y:
				continue
			var distance = abs(x - joueur_actif.grid_x) + abs(y - joueur_actif.grid_y)
			if distance <= portee_effective:
				_dessiner_surbrillance(x, y, COULEUR_SORT)
				
func _dessiner_surbrillance(x: int, y: int, couleur: Color):
	var cx = OFFSET.x + (x - y) * (TILE_W / 2)
	var cy = OFFSET.y + (x + y) * (TILE_H / 2)
	var points = PackedVector2Array([
		Vector2(cx,               cy - TILE_H / 2),
		Vector2(cx + TILE_W / 2, cy),
		Vector2(cx,               cy + TILE_H / 2),
		Vector2(cx - TILE_W / 2, cy),
	])
	draw_colored_polygon(points, couleur)

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

func dessiner_joueur(x: int, y: int, couleur: Color, rayon: int):
	var cx = OFFSET.x + (x - y) * (TILE_W / 2)
	var cy = OFFSET.y + (x + y) * (TILE_H / 2)
	draw_circle(Vector2(cx, cy), rayon, couleur)

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
