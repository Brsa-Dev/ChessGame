# =======================================================
# Board/renderer.gd
# -------------------------------------------------------
# Responsabilité UNIQUE : affichage visuel du plateau.
#
#   - Dessin des cases (losanges isométriques colorés)
#   - Dessin des joueurs (cercles colorés + numéro)
#   - Surbrillances (déplacement jaune, attaque rouge, sort violet)
#   - Dessin des événements (mines, tas de pièces, coffres)
#
# NE contient PAS de logique de gameplay.
# Toutes les données viennent des références injectées par main.gd.
# =======================================================
extends Node2D


# =======================================================
# CONSTANTES — Dimensions isométriques
# =======================================================

const TILE_W           : int = 128  # Largeur d'une case en pixels
const TILE_H           : int = 64   # Hauteur d'une case en pixels
const TAILLE_PLATEAU   : int = 8    # Doit correspondre à board.TAILLE_PLATEAU


# =======================================================
# CONSTANTES — Couleurs des cases (indexées par CaseType)
# =======================================================

const COULEURS_CASES : Dictionary = {
	0: Color(0.85, 0.85, 0.85),  # NORMAL — gris clair
	1: Color(0.9,  0.3,  0.1 ),  # LAVE   — rouge/orange
	2: Color(0.2,  0.5,  0.9 ),  # EAU    — bleu
	3: Color(0.1,  0.1,  0.1 ),  # VIDE   — noir
	4: Color(0.1,  0.6,  0.1 ),  # FORET  — vert
	5: Color(0.5,  0.4,  0.3 ),  # MUR    — marron
	6: Color(0.7,  0.6,  0.1 ),  # TOUR   — doré
}


# =======================================================
# CONSTANTES — Couleurs des joueurs (par index dans la liste)
# =======================================================

const COULEURS_JOUEURS : Array = [
	Color.YELLOW,  # Joueur 1
	Color.CYAN,    # Joueur 2
	Color.GREEN,   # Joueur 3
]


# =======================================================
# CONSTANTES — Surbrillances
# =======================================================

const COULEUR_CASE_ACCESSIBLE : Color = Color(1.0, 1.0, 0.3, 0.5)  # Jaune — déplacement possible
const COULEUR_CASE_ATTAQUABLE : Color = Color(1.0, 0.2, 0.2, 0.5)  # Rouge — ennemi attaquable
const COULEUR_CASE_SORT       : Color = Color(0.7, 0.2, 1.0, 0.5)  # Violet — portée du sort sélectionné


# =======================================================
# CONSTANTES — Événements (mines, pièces, coffres)
# =======================================================

const COULEUR_MINE   : Color = Color(0.85, 0.65, 0.0)  # Doré foncé
const COULEUR_PIECE  : Color = Color(1.0,  0.85, 0.0)  # Jaune vif
const COULEUR_COFFRE : Color = Color(0.6,  0.0,  0.8)  # Violet


# =======================================================
# CONSTANTES — Tailles des éléments visuels
# =======================================================

const RAYON_JOUEUR_NORMAL : float = 14.0  # Joueur inactif
const RAYON_JOUEUR_ACTIF  : float = 18.0  # Joueur dont c'est le tour
const RAYON_MINE          : float = 10.0  # Losange de la mine
const RAYON_PIECE         : float = 6.0   # Tas de pièces
const RAYON_COFFRE        : float = 8.0   # Coffre au trésor
const LARGEUR_BARRE_VIE   : float = 24.0  # Largeur de la barre de vie des mines
const HAUTEUR_BARRE_VIE   : float = 4.0   # Hauteur de la barre de vie des mines


# =======================================================
# RÉFÉRENCES — Injectées par main.gd
# =======================================================

var board         : Node = null  # board.gd — types des cases
var event_manager : Node = null  # event_manager.gd — mines, coffres, tas


# =======================================================
# ÉTAT DU RENDERER
# -------------------------------------------------------
# Mis à jour par input_handler et main.gd après chaque action.
# Tout changement doit être suivi d'un queue_redraw().
# =======================================================

var joueurs            : Array = []    # Liste complète des joueurs
var joueur_actif       : Node  = null  # Joueur dont c'est le tour
var joueur_selectionne : bool  = false # Un joueur est-il sélectionné ?
var sort_selectionne   : int   = -1    # Index du sort actif (-1 = aucun)

# Offset de centrage du plateau — recalculé dans _centrer_plateau()
var _offset : Vector2 = Vector2(440, 80)


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	# Différé pour garantir que le viewport est entièrement initialisé
	call_deferred("_centrer_plateau")

	# Recentre automatiquement le plateau si la fenêtre est redimensionnée
	get_viewport().size_changed.connect(_centrer_plateau)

	print("✅ Renderer prêt !")


# -------------------------------------------------------
# Centre le plateau dans la fenêtre en calculant l'offset.
# L'offset est le point de départ de la case (0,0) en pixels.
# -------------------------------------------------------
func _centrer_plateau() -> void:
	var taille_ecran    : Vector2 = get_viewport().get_visible_rect().size
	var plateau_hauteur : float   = (TAILLE_PLATEAU - 1) * 2.0 * (TILE_H / 2.0)

	_offset = Vector2(
		taille_ecran.x / 2.0,
		(taille_ecran.y - plateau_hauteur) / 2.0
	)

	queue_redraw()


# =======================================================
# DESSIN PRINCIPAL
# -------------------------------------------------------
# Appelé par Godot à chaque queue_redraw().
# Ordre strict : plateau → événements → surbrillances → joueurs
# =======================================================
func _draw() -> void:
	_dessiner_plateau()

	if joueurs.is_empty():
		return

	if event_manager != null:
		_dessiner_evenements()

	if joueur_actif != null and joueur_selectionne:
		_dessiner_surbrillance_deplacement()
		_dessiner_surbrillance_attaque()
		if sort_selectionne >= 0 and sort_selectionne < joueur_actif.sorts.size():
			_dessiner_surbrillance_sort()

	_dessiner_joueurs()


# =======================================================
# DESSIN DU PLATEAU
# =======================================================
func _dessiner_plateau() -> void:
	for x in range(TAILLE_PLATEAU):
		for y in range(TAILLE_PLATEAU):
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

		# Numéro du joueur centré dans le cercle
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
	for x in range(TAILLE_PLATEAU):
		for y in range(TAILLE_PLATEAU):
			if board.case_occupee(x, y):
				continue
			var type_case : int = board.get_case(x, y)
			if type_case in [board.CaseType.VIDE, board.CaseType.MUR]:
				continue
			# Une case avec une mine ne peut pas être un déplacement
			if event_manager != null and event_manager.get_mine_en(x, y) != {}:
				continue
			var cout_reel : int = 2 if type_case == board.CaseType.FORET else 1
			if joueur_actif.pm_actuels >= cout_reel and joueur_actif.peut_se_deplacer_vers(x, y):
				_dessiner_surbrillance_case(x, y, COULEUR_CASE_ACCESSIBLE)

func _dessiner_surbrillance_attaque() -> void:
	# Ennemis attaquables
	for joueur in joueurs:
		if joueur == joueur_actif or not joueur.est_place or joueur.est_mort:
			continue
		if joueur_actif.peut_attaquer(joueur.grid_x, joueur.grid_y):
			_dessiner_surbrillance_case(joueur.grid_x, joueur.grid_y, COULEUR_CASE_ATTAQUABLE)

	# Mines attaquables — même logique que les ennemis
	if event_manager != null:
		for mine in event_manager.mines_actives:
			if joueur_actif.peut_attaquer(mine["x"], mine["y"]):
				_dessiner_surbrillance_case(mine["x"], mine["y"], COULEUR_CASE_ATTAQUABLE)


func _dessiner_surbrillance_sort() -> void:
	var sort       : Resource = joueur_actif.sorts[sort_selectionne]
	var portee_eff : int      = sort.portee + joueur_actif.bonus_range_sorts

	if sort.portee == 0:
		return  # Portée illimitée — pas de surbrillance de zone

	for x in range(TAILLE_PLATEAU):
		for y in range(TAILLE_PLATEAU):
			var distance : int = abs(x - joueur_actif.grid_x) + abs(y - joueur_actif.grid_y)
			if distance <= portee_eff:
				_dessiner_surbrillance_case(x, y, COULEUR_CASE_SORT)


# -------------------------------------------------------
# Dessine un losange coloré sur la case (x, y)
# -------------------------------------------------------
func _dessiner_surbrillance_case(x: int, y: int, couleur: Color) -> void:
	var centre : Vector2 = grid_to_screen(x, y)
	var pts    : Array   = _get_losange_points(centre)
	draw_colored_polygon(PackedVector2Array(pts), couleur)


# =======================================================
# DESSIN DES ÉVÉNEMENTS
# =======================================================
func _dessiner_evenements() -> void:
	for mine in event_manager.mines_actives:
		_dessiner_mine(grid_to_screen(mine["x"], mine["y"]), mine)

	for tas in event_manager.tas_pieces_actifs:
		draw_circle(grid_to_screen(tas["x"], tas["y"]), RAYON_PIECE, COULEUR_PIECE)

	for coffre in event_manager.coffres_actifs:
		draw_circle(grid_to_screen(coffre["x"], coffre["y"]), RAYON_COFFRE, COULEUR_COFFRE)


func _dessiner_mine(centre: Vector2, mine: Dictionary) -> void:
	# Corps de la mine — losange doré
	var pts : Array = _get_losange_points(centre, RAYON_MINE)
	draw_colored_polygon(PackedVector2Array(pts), COULEUR_MINE)

	# Barre de vie proportionnelle aux HP restants
	var pct_vie      : float   = float(mine["hp"]) / float(mine["hp_max"])
	var largeur_vie  : float   = LARGEUR_BARRE_VIE * pct_vie
	var origine      : Vector2 = centre + Vector2(-LARGEUR_BARRE_VIE / 2.0, RAYON_MINE + 2.0)

	draw_rect(Rect2(origine, Vector2(LARGEUR_BARRE_VIE, HAUTEUR_BARRE_VIE)), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(origine, Vector2(largeur_vie, HAUTEUR_BARRE_VIE)),        Color(0.1, 0.9, 0.1))


# =======================================================
# HELPERS — Conversion de coordonnées
# =======================================================

# -------------------------------------------------------
# Convertit une case (x, y) en position pixel sur l'écran.
# Projection isométrique standard — l'axe X va vers le bas-droite,
# l'axe Y va vers le bas-gauche.
# -------------------------------------------------------
func grid_to_screen(x: int, y: int) -> Vector2:
	return _offset + Vector2(
		(x - y) * (TILE_W / 2.0),
		(x + y) * (TILE_H / 2.0)
	)


# -------------------------------------------------------
# Convertit une position pixel en case (x, y).
# Inverse de grid_to_screen — utilisé pour les clics souris.
#
# roundi() est obligatoire ici : int() tronque vers zéro,
# ce qui décale la case détectée dès qu'on clique dans
# la moitié inférieure d'une tuile.
# -------------------------------------------------------
func screen_to_grid(pos: Vector2) -> Vector2i:
	var local : Vector2 = pos - _offset
	var gx    : int     = roundi((local.x / (TILE_W / 2.0) + local.y / (TILE_H / 2.0)) / 2.0)
	var gy    : int     = roundi((local.y / (TILE_H / 2.0) - local.x / (TILE_W / 2.0)) / 2.0)
	return Vector2i(gx, gy)


# -------------------------------------------------------
# Dessine une case isométrique (losange rempli + contour noir)
# -------------------------------------------------------
func dessiner_case(x: int, y: int, couleur: Color) -> void:
	var centre : Vector2 = grid_to_screen(x, y)
	var pts    : Array   = _get_losange_points(centre)
	draw_colored_polygon(PackedVector2Array(pts), couleur)
	draw_polyline(PackedVector2Array(pts + [pts[0]]), Color.BLACK, 1.0)


# -------------------------------------------------------
# Retourne les 4 sommets d'un losange centré sur `centre`.
# rayon_w > 0 : surcharge la demi-largeur (pour les mines)
# -------------------------------------------------------
func _get_losange_points(centre: Vector2, rayon_w: float = -1.0, rayon_h: float = -1.0) -> Array:
	var rw : float = rayon_w if rayon_w > 0.0 else TILE_W / 2.0
	var rh : float = rayon_h if rayon_h > 0.0 else TILE_H / 2.0
	return [
		centre + Vector2(  0, -rh),  # Haut
		centre + Vector2( rw,   0),  # Droite
		centre + Vector2(  0,  rh),  # Bas
		centre + Vector2(-rw,   0),  # Gauche
	]
