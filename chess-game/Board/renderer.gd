# =======================================================
# renderer.gd
# -------------------------------------------------------
# Responsabilité UNIQUE : affichage visuel du plateau.
#
#   - Dessin des cases (couleurs par type)
#   - Dessin des joueurs (cercles colorés)
#   - Surbrillances (déplacement, attaque, sort)
#   - Dessin des événements (mines, tas, coffres)
#
# NE contient PAS de logique de gameplay.
# Toutes les données viennent des références injectées.
# =======================================================
extends Node2D

# -------------------------------------------------------
# Constantes — dimensions des cases isométriques
# -------------------------------------------------------
const TILE_W : int = 128  # Largeur d'une case en pixels
const TILE_H : int = 64   # Hauteur d'une case en pixels
const TAILLE_PLATEAU_CASES : int = 8  # Doit correspondre à board.gd

# -------------------------------------------------------
# Offset de centrage du plateau — calculé dynamiquement
# dans _centrer_plateau() au démarrage
# -------------------------------------------------------
var _offset : Vector2 = Vector2(440, 80)

# -------------------------------------------------------
# Constantes — couleurs des cases par type (CaseType)
# Indexées par la valeur entière de l'enum CaseType
# -------------------------------------------------------
const COULEURS_CASES : Dictionary = {
	0: Color(0.85, 0.85, 0.85),  # NORMAL — gris clair
	1: Color(0.9,  0.3,  0.1 ),  # LAVE   — rouge/orange
	2: Color(0.2,  0.5,  0.9 ),  # EAU    — bleu
	3: Color(0.1,  0.1,  0.1 ),  # VIDE   — noir
	4: Color(0.1,  0.6,  0.1 ),  # FORET  — vert
	5: Color(0.5,  0.4,  0.3 ),  # MUR    — marron
	6: Color(0.7,  0.6,  0.1 ),  # TOUR   — doré
}

# -------------------------------------------------------
# Constantes — couleurs des joueurs (par index dans la liste)
# -------------------------------------------------------
const COULEURS_JOUEURS : Array = [
	Color.YELLOW,  # Joueur 1
	Color.CYAN,    # Joueur 2
	Color.GREEN,   # Joueur 3
]

# -------------------------------------------------------
# Constantes — surbrillances
# -------------------------------------------------------
const COULEUR_CASE_ACCESSIBLE : Color = Color(1.0, 1.0, 0.3, 0.5)  # Jaune transparent — déplacement
const COULEUR_CASE_ATTAQUABLE : Color = Color(1.0, 0.2, 0.2, 0.5)  # Rouge transparent — attaque
const COULEUR_CASE_SORT       : Color = Color(0.7, 0.2, 1.0, 0.5)  # Violet transparent — portée sort

# -------------------------------------------------------
# Constantes — événements (mines, pièces, coffres)
# -------------------------------------------------------
const COULEUR_MINE   : Color = Color(0.85, 0.65, 0.0)  # Doré foncé
const COULEUR_PIECE  : Color = Color(1.0,  0.85, 0.0)  # Jaune vif
const COULEUR_COFFRE : Color = Color(0.6,  0.0,  0.8)  # Violet

# -------------------------------------------------------
# Constantes — tailles des éléments visuels
# -------------------------------------------------------
const RAYON_JOUEUR_NORMAL  : float = 14.0  # Rayon du cercle joueur inactif
const RAYON_JOUEUR_ACTIF   : float = 18.0  # Rayon du cercle joueur dont c'est le tour
const RAYON_MINE           : float = 10.0  # Rayon du losange mine
const RAYON_PIECE          : float = 6.0   # Rayon du cercle tas de pièces
const RAYON_COFFRE         : float = 8.0   # Rayon du cercle coffre
const LARGEUR_BARRE_VIE    : float = 24.0  # Largeur de la barre de vie des mines
const HAUTEUR_BARRE_VIE    : float = 4.0   # Hauteur de la barre de vie des mines

# -------------------------------------------------------
# Références injectées par main.gd dans _ready()
# -------------------------------------------------------
var board         : Node  = null  # board.gd — types des cases
var event_manager : Node  = null  # event_manager.gd — mines, coffres, tas

# -------------------------------------------------------
# État du renderer — mis à jour par input_handler / main.gd
# -------------------------------------------------------
var joueurs           : Array = []    # Liste complète des joueurs
var joueur_actif      : Node  = null  # Joueur dont c'est le tour
var joueur_selectionne: bool  = false # Un joueur est-il sélectionné ?
var sort_selectionne  : int   = -1    # Index du sort actif (-1 = aucun)


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	# Différé pour garantir que le viewport est prêt
	call_deferred("_centrer_plateau")
	
	# Reconnecte automatiquement le centrage à chaque redimensionnement de fenêtre
	get_viewport().size_changed.connect(_centrer_plateau)
	print("✅ Renderer prêt !")


# -------------------------------------------------------
# Centre le plateau dans la fenêtre
# -------------------------------------------------------
func _centrer_plateau() -> void:
	var taille_ecran    : Vector2 = get_viewport().get_visible_rect().size
	var plateau_hauteur : float   = (TAILLE_PLATEAU_CASES - 1) * 2.0 * (TILE_H / 2.0)

	_offset = Vector2(
		taille_ecran.x / 2.0,
		(taille_ecran.y - plateau_hauteur) / 2.0
	)

	queue_redraw()


# =======================================================
# DESSIN PRINCIPAL
# -------------------------------------------------------
# Appelé par Godot à chaque queue_redraw()
# =======================================================
func _draw() -> void:
	# 1. Plateau de cases
	_dessiner_plateau()

	if joueurs.is_empty():
		return

	# 2. Événements (mines, pièces, coffres)
	if event_manager != null:
		_dessiner_evenements()

	# 3. Surbrillances (déplacement, attaque, sort)
	if joueur_actif != null and joueur_selectionne:
		_dessiner_surbrillance_deplacement()
		_dessiner_surbrillance_attaque()
		if sort_selectionne >= 0 and sort_selectionne < joueur_actif.sorts.size():
			_dessiner_surbrillance_sort()

	# 4. Joueurs
	_dessiner_joueurs()


# =======================================================
# DESSIN DU PLATEAU
# =======================================================
func _dessiner_plateau() -> void:
	for x in range(8):
		for y in range(8):
			var type_case : int   = board.get_case(x, y) if board != null else 0
			var couleur   : Color = COULEURS_CASES.get(type_case, Color.WHITE)
			dessiner_case(x, y, couleur)


# =======================================================
# DESSIN DES JOUEURS
# =======================================================
func _dessiner_joueurs() -> void:
	for i in range(joueurs.size()):
		var joueur : Node = joueurs[i]
		if not joueur.est_place or joueur.est_mort:
			continue

		var centre : Vector2 = grid_to_screen(joueur.grid_x, joueur.grid_y)
		var couleur : Color  = COULEURS_JOUEURS[i] if i < COULEURS_JOUEURS.size() else Color.WHITE
		var rayon   : float  = RAYON_JOUEUR_ACTIF if joueur == joueur_actif else RAYON_JOUEUR_NORMAL

		draw_circle(centre, rayon, couleur)

		# Numéro du joueur au centre du cercle
		draw_string(
			ThemeDB.fallback_font,
			centre + Vector2(-5, 5),
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color.BLACK
		)


# =======================================================
# SURBRILLANCES
# =======================================================

func _dessiner_surbrillance_deplacement() -> void:
	for x in range(8):
		for y in range(8):
			if board.case_occupee(x, y):
				continue
			var type_case : int = board.get_case(x, y)
			if type_case in [board.CaseType.VIDE, board.CaseType.MUR]:
				continue
			if joueur_actif.peut_se_deplacer_vers(x, y):
				_dessiner_surbrillance_case(x, y, COULEUR_CASE_ACCESSIBLE)


func _dessiner_surbrillance_attaque() -> void:
	for joueur in joueurs:
		if joueur == joueur_actif or not joueur.est_place or joueur.est_mort:
			continue
		if joueur_actif.peut_attaquer(joueur.grid_x, joueur.grid_y):
			_dessiner_surbrillance_case(joueur.grid_x, joueur.grid_y, COULEUR_CASE_ATTAQUABLE)

		# Surbrillance des mines attaquables
		if event_manager != null:
			for mine in event_manager.mines_actives:
				if joueur_actif.peut_attaquer(mine["x"], mine["y"]):
					_dessiner_surbrillance_case(mine["x"], mine["y"], COULEUR_CASE_ATTAQUABLE)


func _dessiner_surbrillance_sort() -> void:
	var sort       : Resource = joueur_actif.sorts[sort_selectionne]
	var portee_eff : int      = sort.portee + joueur_actif.bonus_range_sorts

	for x in range(8):
		for y in range(8):
			if sort.portee == 0:
				continue
			var distance : int = abs(x - joueur_actif.grid_x) + abs(y - joueur_actif.grid_y)
			if distance <= portee_eff:
				_dessiner_surbrillance_case(x, y, COULEUR_CASE_SORT)


func _dessiner_surbrillance_case(x: int, y: int, couleur: Color) -> void:
	var centre : Vector2 = grid_to_screen(x, y)
	var pts    : Array   = _get_losange_points(centre)
	draw_colored_polygon(PackedVector2Array(pts), couleur)


# =======================================================
# DESSIN DES ÉVÉNEMENTS
# =======================================================
func _dessiner_evenements() -> void:
	# Mines d'or
	for mine in event_manager.mines_actives:
		var centre : Vector2 = grid_to_screen(mine["x"], mine["y"])
		_dessiner_mine(centre, mine)

	# Tas de pièces (mines détruites)
	for tas in event_manager.tas_pieces_actifs:
		var centre : Vector2 = grid_to_screen(tas["x"], tas["y"])
		draw_circle(centre, RAYON_PIECE, COULEUR_PIECE)

	# Coffres au trésor
	for coffre in event_manager.coffres_actifs:
		var centre : Vector2 = grid_to_screen(coffre["x"], coffre["y"])
		draw_circle(centre, RAYON_COFFRE, COULEUR_COFFRE)


func _dessiner_mine(centre: Vector2, mine: Dictionary) -> void:
	# Corps de la mine — losange doré
	var pts : Array = _get_losange_points(centre, RAYON_MINE)
	draw_colored_polygon(PackedVector2Array(pts), COULEUR_MINE)

	# Barre de vie — proportionnelle aux HP restants
	var pct_vie      : float   = float(mine["hp"]) / float(mine["hp_max"])
	var largeur_vie  : float   = LARGEUR_BARRE_VIE * pct_vie
	var origine_barre: Vector2 = centre + Vector2(-LARGEUR_BARRE_VIE / 2.0, RAYON_MINE + 2.0)
	draw_rect(
		Rect2(origine_barre, Vector2(LARGEUR_BARRE_VIE, HAUTEUR_BARRE_VIE)),
		Color(0.3, 0.3, 0.3)  # Fond gris
	)
	draw_rect(
		Rect2(origine_barre, Vector2(largeur_vie, HAUTEUR_BARRE_VIE)),
		Color(0.1, 0.9, 0.1)  # Vie verte
	)


# =======================================================
# HELPERS — Conversion de coordonnées
# =======================================================

# -------------------------------------------------------
# Convertit une position grille (x, y) en position écran
# Projection isométrique standard
# -------------------------------------------------------
func grid_to_screen(x: int, y: int) -> Vector2:
	return _offset + Vector2(
		(x - y) * (TILE_W / 2.0),
		(x + y) * (TILE_H / 2.0)
	)


# -------------------------------------------------------
# Convertit une position écran en coordonnées grille
# Inverse de grid_to_screen — utilisé pour les clics souris
# -------------------------------------------------------
func screen_to_grid(pos: Vector2) -> Vector2i:
	var local : Vector2 = pos - _offset
	var gx    : int     = int((local.x / (TILE_W / 2.0) + local.y / (TILE_H / 2.0)) / 2.0)
	var gy    : int     = int((local.y / (TILE_H / 2.0) - local.x / (TILE_W / 2.0)) / 2.0)
	return Vector2i(gx, gy)


# -------------------------------------------------------
# Dessine une case isométrique (losange) à la position grille
# -------------------------------------------------------
func dessiner_case(x: int, y: int, couleur: Color) -> void:
	var centre : Vector2 = grid_to_screen(x, y)
	var pts    : Array   = _get_losange_points(centre)
	draw_colored_polygon(PackedVector2Array(pts), couleur)
	draw_polyline(PackedVector2Array(pts + [pts[0]]), Color.BLACK, 1.0)


# -------------------------------------------------------
# Retourne les 4 sommets d'un losange centré en `centre`
# rayon optionnel pour les mines (plus petit que les cases)
# -------------------------------------------------------
func _get_losange_points(centre: Vector2, rayon_w: float = -1.0, rayon_h: float = -1.0) -> Array:
	var rw : float = rayon_w if rayon_w > 0.0 else TILE_W / 2.0
	var rh : float = rayon_h if rayon_h > 0.0 else TILE_H / 2.0
	return [
		centre + Vector2(0,   -rh),  # Haut
		centre + Vector2(rw,   0 ),  # Droite
		centre + Vector2(0,    rh),  # Bas
		centre + Vector2(-rw,  0 ),  # Gauche
	]
