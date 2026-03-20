# =======================================================
# Board/renderer.gd
# -------------------------------------------------------
# Responsabilité UNIQUE : affichage visuel 3D du plateau.
#
#   - Instancie les modèles .glb des cases sur la grille
#   - Gère les pions joueurs (Étape B)
#   - Surbrillances déplacement / attaque / sort (Étape C)
#   - Événements : mines, coffres, tas de pièces (Étape E)
#
# NE contient PAS de logique de gameplay.
# Toutes les données viennent des références injectées par main.gd.
#
# Passage 2D → 3D :
#   - grid_to_screen()  →  grid_to_world()
#   - draw_colored_polygon() → instanciation de .glb
#   - queue_redraw()    →  rafraichir()
# =======================================================
extends Node3D


# =======================================================
# CONSTANTES — Grille
# =======================================================

# Taille d'une case en unités Godot (1 case = 1 unité Blender exportée)
const CASE_SIZE : float = 1.50

# Nombre de cases du plateau (doit correspondre à board.TAILLE_PLATEAU)
const TAILLE_PLATEAU : int = 8

# Décalage pour centrer le plateau 8×8 sur l'origine mondiale.
# Sans offset, le plateau irait de (0,0,0) à (7,0,7).
# Avec offset (-3.5, 0, -3.5), il est centré sur (0,0,0).
# La caméra à (10,10,10) pointe vers l'origine → plateau bien cadré.
const OFFSET_PLATEAU : Vector3 = Vector3(-3.5, 0.0, -3.5)

# Hauteur des plans de surbrillance — légèrement au-dessus des cases
# pour éviter le Z-fighting avec la surface des .glb
const HAUTEUR_SURBRILLANCE : float = 0.11

# Taille du plan de surbrillance — légèrement plus petit que la case
# pour que les bords des cases restent visibles
const TAILLE_SURBRILLANCE : float = 0.9


# =======================================================
# CONSTANTES — Pions joueurs
# =======================================================

# Hauteur des pions selon la case occupée
const HAUTEUR_NORMALE : float = 0.1
const HAUTEUR_TOUR    : float = 0.5  # Surélevé au sommet de la tour


# =======================================================
# SCÈNES PRÉCHARGÉES — Cases
# -------------------------------------------------------
# preload() est exécuté à la compilation — pas de latence en jeu.
# Chaque CaseType a sa scène correspondante.
# VIDE n'a pas de scène : la case est simplement invisible.
# =======================================================
const SCENE_CASE_NORMAL_WHITE : PackedScene = preload("res://Assets/Cases/case_normal_white.glb")
const SCENE_CASE_NORMAL_BLACK : PackedScene = preload("res://Assets/Cases/case_normal_black.glb")
const SCENE_CASE_LAVE         : PackedScene = preload("res://Assets/Cases/case_lave.glb")
const SCENE_CASE_EAU          : PackedScene = preload("res://Assets/Cases/case_eau.glb")
const SCENE_CASE_FORET        : PackedScene = preload("res://Assets/Cases/case_foret.glb")
const SCENE_CASE_MUR          : PackedScene = preload("res://Assets/Cases/case_mur.glb")
const SCENE_CASE_TOUR         : PackedScene = preload("res://Assets/Cases/case_tour.glb")


# =======================================================
# SCÈNES PRÉCHARGÉES — Joueurs
# -------------------------------------------------------
# Chaque classe a son propre .glb complet (pion + accessoires
# déjà intégrés et positionnés depuis Blender).
# =======================================================
const SCENE_PION_GUERRIER : PackedScene = preload("res://Assets/Personnages/guerrier/pion_guerrier.glb")
const SCENE_PION_MAGE     : PackedScene = preload("res://Assets/Personnages/mage/pion_mage.glb")
const SCENE_PION_ARCHER   : PackedScene = preload("res://Assets/Personnages/archer/pion_archer.glb")
const SCENE_PION_FRIPON   : PackedScene = preload("res://Assets/Personnages/fripon/pion_fripon.glb")


# =======================================================
# SCÈNES PRÉCHARGÉES — Événements
# =======================================================
const SCENE_MINE       : PackedScene = preload("res://Assets/Evenements/charriot.glb")
const SCENE_COFFRE     : PackedScene = preload("res://Assets/Evenements/coffre.glb")
const SCENE_TAS_PIECES : PackedScene = preload("res://Assets/Evenements/tas_pieces.glb")


# =======================================================
# RÉFÉRENCES — Injectées par main.gd dans _ready()
# =======================================================

var board         : Node  = null  # board.gd — état du plateau
var event_manager : Node  = null  # event_manager.gd — événements actifs
var joueurs       : Array[Node] = []  # Liste des joueurs

# Joueur dont c'est le tour (pour l'affichage actif)
var joueur_actif : Node = null

# État de sélection — utilisés aux Étapes B et C
var joueur_selectionne : bool = false
var sort_selectionne   : int  = -1

# Référence à la Camera3D — injectée par main.gd
# Nécessaire pour projeter le rayon depuis la caméra vers le sol
var camera : Camera3D = null


# =======================================================
# ÉTAT INTERNE — Nœuds des cases instanciés
# -------------------------------------------------------
# Dictionnaire "x,y" → Node3D instancié sur le plateau.
# Permet de remplacer une case précise sans tout reconstruire.
# =======================================================
var _noeuds_cases : Dictionary = {}

# Snapshot du dernier type affiché pour chaque case.
# Sert à détecter les changements dans rafraichir() :
# on ne remplace un nœud QUE si son type a changé.
var _types_affiches : Dictionary = {}

# Dictionnaire index_joueur (int) → Node3D racine du pion instancié.
var _noeuds_joueurs : Dictionary = {}

# Liste des nœuds de surbrillance actifs (MeshInstance3D).
# Tous supprimés et recréés à chaque rafraichir().
var _noeuds_surbrillances : Array[Node3D] = []

# Nœuds des événements actifs — recréés à chaque rafraichir()
var _noeuds_evenements : Dictionary = {}


# =======================================================
# INITIALISATION
# =======================================================

func _ready() -> void:
	# Les références (board, joueurs...) sont injectées par main.gd
	# APRÈS _ready(). On construit le plateau dans rafraichir(),
	# appelé explicitement par main.gd une fois tout injecté.
	pass


# =======================================================
# POINT D'ENTRÉE PUBLIC — Mise à jour visuelle
# -------------------------------------------------------
# Appelée par main.gd à chaque changement d'état du jeu.
#
# Stratégie : on ne détruit/recrée QUE les cases dont le type
# a changé depuis le dernier appel.
#
# =======================================================
func rafraichir() -> void:
	if board == null:
		push_error("renderer.rafraichir() — board est null, injection manquante !")
		return

	_mettre_a_jour_cases()
	_mettre_a_jour_joueurs()
	_mettre_a_jour_surbrillances()
	_mettre_a_jour_evenements()


# =======================================================
# CASES — Construction et mise à jour
# =======================================================

# -------------------------------------------------------
# Parcourt les 64 cases et met à jour uniquement celles
# dont le type a changé depuis le dernier rafraichir().
# Premier appel : toutes les cases sont créées.
# -------------------------------------------------------
func _mettre_a_jour_cases() -> void:
	for x in range(TAILLE_PLATEAU):
		for y in range(TAILLE_PLATEAU):
			var cle         : String = "%d,%d" % [x, y]
			var type_actuel : int    = board.get_case(x, y)

			if _types_affiches.get(cle, -1) == type_actuel:
				continue

			if _noeuds_cases.has(cle):
				_noeuds_cases[cle].queue_free()
				_noeuds_cases.erase(cle)

			_placer_case(x, y, type_actuel, cle)
			_types_affiches[cle] = type_actuel


# -------------------------------------------------------
# Instancie le bon .glb pour la case (x, y) selon son type.
# La case VIDE ne génère aucun nœud — elle est invisible.
#
# Le damier noir/blanc est déterminé par (x + y) % 2 :
#   pair  → white
#   impair → black
# -------------------------------------------------------
func _placer_case(x: int, y: int, type_case: int, cle: String) -> void:
	if type_case == board.CaseType.VIDE:
		return

	var scene : PackedScene = _get_scene_case(x, y, type_case)
	if scene == null:
		push_warning("renderer._placer_case() — aucune scène pour le type %d" % type_case)
		return

	var noeud : Node3D = scene.instantiate()
	noeud.position = grid_to_world(x, y)
	add_child(noeud)
	_noeuds_cases[cle] = noeud


# -------------------------------------------------------
# Retourne la scène PackedScene correspondant à un CaseType.
# Pour NORMAL, alterne blanc/noir selon la parité (x + y).
# -------------------------------------------------------
func _get_scene_case(x: int, y: int, type_case: int) -> PackedScene:
	match type_case:
		board.CaseType.NORMAL:
			return SCENE_CASE_NORMAL_WHITE if (x + y) % 2 == 0 else SCENE_CASE_NORMAL_BLACK
		board.CaseType.LAVE:   return SCENE_CASE_LAVE
		board.CaseType.EAU:    return SCENE_CASE_EAU
		board.CaseType.FORET:  return SCENE_CASE_FORET
		board.CaseType.MUR:    return SCENE_CASE_MUR
		board.CaseType.TOUR:   return SCENE_CASE_TOUR
	return null


# =======================================================
# HELPERS — Conversion de coordonnées
# =======================================================

# -------------------------------------------------------
# Convertit une case (x, y) de la grille en position 3D.
#
# Le plateau est centré sur l'origine grâce à OFFSET_PLATEAU.
# L'axe X de la grille correspond à l'axe X de Godot.
# L'axe Y de la grille correspond à l'axe Z de Godot
#   (en 3D Godot, Y = hauteur — on joue sur un plan horizontal XZ).
# -------------------------------------------------------
func grid_to_world(x: int, y: int) -> Vector3:
	return OFFSET_PLATEAU + Vector3(x * CASE_SIZE, 0.0, y * CASE_SIZE)


# =======================================================
# CONVERSION CLIC SOURIS → CASE DE GRILLE (Raycast 3D)
# -------------------------------------------------------
# 1. Projette un rayon depuis la caméra à travers le pixel cliqué
# 2. Intersecte un plan horizontal y=0 (le sol)
# 3. Inverse grid_to_world() pour obtenir (grid_x, grid_y)
# 4. Vérifie les bornes du plateau
#
# Retourne Vector2i(-1, -1) si le clic est hors plateau.
# =======================================================
func screen_to_grid(pos: Vector2) -> Vector2i:
	if camera == null:
		push_warning("renderer.screen_to_grid() — camera est null !")
		return Vector2i(-1, -1)

	var origine   : Vector3 = camera.project_ray_origin(pos)
	var direction : Vector3 = camera.project_ray_normal(pos)

	# Intersection rayon / plan horizontal y=0
	if abs(direction.y) < 0.001:
		return Vector2i(-1, -1)

	var t         : float   = -origine.y / direction.y
	var point_sol : Vector3 = origine + direction * t

	var gx : int = roundi((point_sol.x - OFFSET_PLATEAU.x) / CASE_SIZE)
	var gy : int = roundi((point_sol.z - OFFSET_PLATEAU.z) / CASE_SIZE)

	if gx < 0 or gx >= TAILLE_PLATEAU or gy < 0 or gy >= TAILLE_PLATEAU:
		return Vector2i(-1, -1)

	return Vector2i(gx, gy)


# -------------------------------------------------------
# Calcule toutes les cases réellement atteignables depuis
# la position (jx, jy) avec pm_disponibles PM.
#
# Utilise un BFS (Breadth-First Search) — simule le déplacement
# case par case. Un MUR ou VIDE bloque TOUTES les cases derrière.
# Une case Forêt coûte 2 PM. Les cases occupées ne sont pas
# atteignables mais ne bloquent PAS le chemin.
#
# Retourne un dictionnaire "x,y" → coût PM pour y arriver.
# -------------------------------------------------------
func _calculer_cases_accessibles(jx: int, jy: int, pm_disponibles: int) -> Dictionary:
	var atteignables : Dictionary = {}
	var file         : Array      = [[jx, jy, 0]]
	var visites      : Dictionary = {}
	visites["%d,%d" % [jx, jy]] = true

	const DIRECTIONS : Array[Vector2i] = [
		Vector2i( 1,  0),
		Vector2i(-1,  0),
		Vector2i( 0,  1),
		Vector2i( 0, -1),
	]

	while not file.is_empty():
		var courant : Array = file.pop_front()
		var cx      : int   = courant[0]
		var cy      : int   = courant[1]
		var pm_used : int   = courant[2]

		for dir in DIRECTIONS:
			var nx  : int    = cx + dir.x
			var ny  : int    = cy + dir.y
			var cle : String = "%d,%d" % [nx, ny]

			if nx < 0 or nx >= TAILLE_PLATEAU or ny < 0 or ny >= TAILLE_PLATEAU:
				continue
			if visites.has(cle):
				continue

			var type_case : int = board.get_case(nx, ny)

			if type_case == board.CaseType.VIDE or type_case == board.CaseType.MUR:
				continue

			# Forêt coûte 2 PM, toutes les autres cases coûtent 1
			var cout       : int = 2 if type_case == board.CaseType.FORET else 1
			var nouveau_pm : int = pm_used + cout

			if nouveau_pm > pm_disponibles:
				continue

			visites[cle] = true

			# Case occupée : on longe mais on ne s'arrête pas
			if board.case_occupee(nx, ny):
				file.append([nx, ny, nouveau_pm])
				continue

			atteignables[cle] = nouveau_pm
			file.append([nx, ny, nouveau_pm])

	return atteignables


# =======================================================
# JOUEURS — Affichage des pions 3D
# =======================================================

# -------------------------------------------------------
# Met à jour l'affichage de tous les joueurs.
# - Crée le nœud pion si le joueur vient d'être placé
# - Déplace le nœud si le joueur a bougé
# - Supprime le nœud si le joueur est mort
# -------------------------------------------------------
func _mettre_a_jour_joueurs() -> void:
	for i in range(joueurs.size()):
		var joueur : Node   = joueurs[i]
		var cle    : String = str(i)

		if joueur.est_mort or not joueur.est_place:
			if _noeuds_joueurs.has(cle):
				_noeuds_joueurs[cle].queue_free()
				_noeuds_joueurs.erase(cle)
			continue

		if not _noeuds_joueurs.has(cle):
			var noeud_pion : Node3D = _creer_pion(joueur)
			add_child(noeud_pion)
			_noeuds_joueurs[cle] = noeud_pion

		var pos_monde : Vector3 = grid_to_world(joueur.grid_x, joueur.grid_y)
		var type_case : int     = board.get_case(joueur.grid_x, joueur.grid_y)

		# Les pions sur une case TOUR sont surélevés visuellement
		var hauteur : float = HAUTEUR_TOUR if type_case == board.CaseType.TOUR else HAUTEUR_NORMALE
		_noeuds_joueurs[cle].position = Vector3(pos_monde.x, hauteur, pos_monde.z)


# -------------------------------------------------------
# Crée le pion 3D complet pour un joueur selon sa classe.
# Chaque classe a son propre .glb avec pion + accessoires
# déjà positionnés correctement depuis Blender.
# -------------------------------------------------------
func _creer_pion(joueur: Node) -> Node3D:
	var scene : PackedScene = _get_scene_pion(joueur)
	var noeud : Node3D      = scene.instantiate()
	return noeud


# -------------------------------------------------------
# Retourne la scène du pion selon la classe du joueur.
# -------------------------------------------------------
func _get_scene_pion(joueur: Node) -> PackedScene:
	match joueur.get_classe():
		"guerrier": return SCENE_PION_GUERRIER
		"mage":     return SCENE_PION_MAGE
		"archer":   return SCENE_PION_ARCHER
		"fripon":   return SCENE_PION_FRIPON
	push_warning("renderer._get_scene_pion() — classe inconnue pour %s" % joueur.name)
	return SCENE_PION_GUERRIER


# =======================================================
# SURBRILLANCES — Plans transparents au-dessus des cases
# =======================================================

# -------------------------------------------------------
# Supprime toutes les surbrillances existantes et recrée
# celles qui correspondent à l'état de sélection actuel.
# -------------------------------------------------------
func _mettre_a_jour_surbrillances() -> void:
	for noeud in _noeuds_surbrillances:
		noeud.queue_free()
	_noeuds_surbrillances.clear()

	if joueur_actif == null:
		return

	# Sort sélectionné → surbrillance violette UNIQUEMENT
	if sort_selectionne >= 0 and sort_selectionne < joueur_actif.sorts.size():
		_afficher_surbrillance_sort()
		return

	if not joueur_selectionne:
		return

	_afficher_surbrillance_deplacement()
	_afficher_surbrillance_attaque()


# -------------------------------------------------------
# Surbrillance jaune — cases accessibles en déplacement.
# Utilise le BFS (obstacles et coût forêt pris en compte).
# -------------------------------------------------------
func _afficher_surbrillance_deplacement() -> void:
	var cases : Dictionary = _calculer_cases_accessibles(
		joueur_actif.grid_x,
		joueur_actif.grid_y,
		joueur_actif.pm_actuels
	)

	for cle in cases.keys():
		var coords : PackedStringArray = cle.split(",")
		_creer_surbrillance(coords[0].to_int(), coords[1].to_int(), Color(1.0, 1.0, 0.3, 0.45))


# -------------------------------------------------------
# Surbrillance rouge — ennemis à portée d'attaque de base.
# -------------------------------------------------------
func _afficher_surbrillance_attaque() -> void:
	if joueur_actif.pm_actuels <= 0:
		return
	if joueur_actif.a_attaque_ce_tour:
		return

	var portee : int = joueur_actif.attaque_portee
	var jx     : int = joueur_actif.grid_x
	var jy     : int = joueur_actif.grid_y

	for ennemi in joueurs:
		if ennemi == joueur_actif:
			continue
		if not ennemi.est_place or ennemi.est_mort:
			continue
		var dist : int = abs(ennemi.grid_x - jx) + abs(ennemi.grid_y - jy)
		if dist <= portee:
			_creer_surbrillance(ennemi.grid_x, ennemi.grid_y, Color(1.0, 0.2, 0.2, 0.45))


# -------------------------------------------------------
# Surbrillance violette — portée du sort actuellement sélectionné.
# -------------------------------------------------------
func _afficher_surbrillance_sort() -> void:
	const SORTS_AUTO_CIBLANTS : Array[String] = ["guerrier_rage", "fripon_lame", "fripon_frenesie"]

	var sort   : Sort = joueur_actif.sorts[sort_selectionne]
	var portee : int  = sort.portee
	var jx     : int  = joueur_actif.grid_x
	var jy     : int  = joueur_actif.grid_y

	# Sorts auto-ciblants — surbrillance verte uniquement sur la case du lanceur
	if sort.id in SORTS_AUTO_CIBLANTS:
		_creer_surbrillance(jx, jy, Color(0.2, 1.0, 0.4, 0.6))
		return

	# Portée 0 = portée illimitée (Tempête Arcanique) → tout le plateau
	for x in range(TAILLE_PLATEAU):
		for y in range(TAILLE_PLATEAU):
			if x == jx and y == jy:
				continue
			var dist : int = abs(x - jx) + abs(y - jy)
			if portee == 0 or dist <= portee:
				_creer_surbrillance(x, y, Color(0.7, 0.2, 1.0, 0.45))


# -------------------------------------------------------
# Crée un plan plat transparent (MeshInstance3D) sur la case (x, y).
# -------------------------------------------------------
func _creer_surbrillance(x: int, y: int, couleur: Color) -> void:
	var mesh_instance := MeshInstance3D.new()

	var plan := PlaneMesh.new()
	plan.size = Vector2(TAILLE_SURBRILLANCE, TAILLE_SURBRILLANCE)
	mesh_instance.mesh = plan

	var mat := StandardMaterial3D.new()
	mat.albedo_color             = couleur
	mat.transparency             = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode             = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

	var pos : Vector3 = grid_to_world(x, y)
	mesh_instance.position = Vector3(pos.x, HAUTEUR_SURBRILLANCE, pos.z)

	add_child(mesh_instance)
	_noeuds_surbrillances.append(mesh_instance)


# =======================================================
# ÉVÉNEMENTS — Mines, coffres, tas de pièces
# =======================================================

# -------------------------------------------------------
# Supprime tous les nœuds d'événements existants et
# recrée ceux qui sont actuellement actifs dans event_manager.
# -------------------------------------------------------
func _mettre_a_jour_evenements() -> void:
	if event_manager == null:
		return

	for noeud in _noeuds_evenements.values():
		noeud.queue_free()
	_noeuds_evenements.clear()

	for mine in event_manager.mines_actives:
		_placer_evenement(
			mine["x"], mine["y"],
			SCENE_MINE,
			"mine_%d_%d" % [mine["x"], mine["y"]],
			0.57
		)

	for tas in event_manager.tas_pieces_actifs:
		_placer_evenement(
			tas["x"], tas["y"],
			SCENE_TAS_PIECES,
			"tas_%d_%d" % [tas["x"], tas["y"]],
			0.15
		)

	for coffre in event_manager.coffres_actifs:
		_placer_evenement(
			coffre["x"], coffre["y"],
			SCENE_COFFRE,
			"coffre_%d_%d" % [coffre["x"], coffre["y"]],
			0.35
		)


# -------------------------------------------------------
# Instancie un .glb d'événement et le positionne sur la case (x, y).
# hauteur_y : décalage vertical pour poser l'objet sur la case.
# -------------------------------------------------------
func _placer_evenement(x: int, y: int, scene: PackedScene, cle: String, hauteur_y: float) -> void:
	var noeud : Node3D  = scene.instantiate()
	var pos   : Vector3 = grid_to_world(x, y)
	noeud.position = Vector3(pos.x, hauteur_y, pos.z)
	add_child(noeud)

	# Barre de vie uniquement pour les mines
	if cle.begins_with("mine_"):
		for mine in event_manager.mines_actives:
			if mine["x"] == x and mine["y"] == y:
				var label := Label3D.new()
				label.name      = "BarreVie"
				label.position  = Vector3(0.0, 0.9, 0.0)
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.font_size = 28
				label.modulate  = Color(0.1, 0.9, 0.1)
				label.text      = "❤️ %d / %d" % [mine["hp"], mine["hp_max"]]
				noeud.add_child(label)
				break

	_noeuds_evenements[cle] = noeud
