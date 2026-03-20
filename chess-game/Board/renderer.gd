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
const CASE_SIZE    : float = 1.50


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
const TAILLE_SURBRILLANCE  : float = 0.9


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

# Liste des joueurs (injectée par main.gd)
var joueurs : Array = []

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
# Ex : quand la Lave temporaire expire, on remet la case NORMAL.
# =======================================================
var _noeuds_cases : Dictionary = {}

# Snapshot du dernier type affiché pour chaque case.
# Sert à détecter les changements dans rafraichir() :
# on ne remplace un nœud QUE si son type a changé.
# Format identique : "x,y" → CaseType (int)
var _types_affiches : Dictionary = {}

# Dictionnaire index_joueur (int) → Node3D racine du pion instancié.
# Permet de déplacer ou supprimer le pion d'un joueur précis.
var _noeuds_joueurs : Dictionary = {}

# Liste des nœuds de surbrillance actifs (MeshInstance3D).
# Tous supprimés et recréés à chaque rafraichir().
var _noeuds_surbrillances : Array = []

# Nœuds des événements actifs — recréés à chaque rafraichir()
# Clé : identifiant unique de l'événement ("mine_x_y", "coffre_x_y", etc.)
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
# rafraichir() est la nouvelle API principale (ancienne : queue_redraw()).
# Appelée par main.gd à chaque changement d'état du jeu.
#
# Stratégie : on ne détruit/recrée QUE les cases dont le type
# a changé depuis le dernier appel. C'est plus performant
# que de tout reconstruire à chaque fin de tour.
#
# queue_redraw() — shim de compatibilité
# -------------------------------------------------------
# Node3D n'hérite pas de CanvasItem, donc queue_redraw()
# n'existe pas nativement. Ce shim redirige les anciens
# appels de main.gd vers rafraichir() pendant la migration.
# À supprimer une fois main.gd mis à jour (Étape D).
# =======================================================
func queue_redraw() -> void:
	rafraichir()


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
			var cle        : String = "%d,%d" % [x, y]
			var type_actuel : int   = board.get_case(x, y)

			# Si le type n'a pas changé, on ne touche à rien
			if _types_affiches.get(cle, -1) == type_actuel:
				continue

			# Supprime l'ancien nœud s'il existe
			if _noeuds_cases.has(cle):
				_noeuds_cases[cle].queue_free()
				_noeuds_cases.erase(cle)

			# Instancie le nouveau nœud selon le type
			_placer_case(x, y, type_actuel, cle)

			# Mémorise le type affiché
			_types_affiches[cle] = type_actuel


# -------------------------------------------------------
# Instancie le bon .glb pour la case (x, y) selon son type.
# La case VIDE ne génère aucun nœud — elle est invisible.
#
# Le damier noir/blanc est déterminé par (x + y) % 2 :
#   pair  → white
#   impair → black
# (uniquement pour les cases NORMAL)
# -------------------------------------------------------
func _placer_case(x: int, y: int, type_case: int, cle: String) -> void:
	# La case VIDE est un trou — rien à afficher
	if type_case == 3:  # CaseType.VIDE
		return

	# Sélectionne la scène selon le type
	var scene : PackedScene = _get_scene_case(x, y, type_case)
	if scene == null:
		push_warning("renderer._placer_case() — aucune scène pour le type %d" % type_case)
		return

	# Instancie et positionne le nœud 3D
	var noeud : Node3D = scene.instantiate()
	noeud.position = grid_to_world(x, y)
	add_child(noeud)

	# Stocke la référence pour mise à jour future
	_noeuds_cases[cle] = noeud


# -------------------------------------------------------
# Retourne la scène PackedScene correspondant à un CaseType.
# Pour NORMAL, alterne blanc/noir selon la parité (x + y).
# -------------------------------------------------------
func _get_scene_case(x: int, y: int, type_case: int) -> PackedScene:
	match type_case:
		0:  # NORMAL — damier blanc/noir
			return SCENE_CASE_NORMAL_WHITE if (x + y) % 2 == 0 else SCENE_CASE_NORMAL_BLACK
		1:  return SCENE_CASE_LAVE
		2:  return SCENE_CASE_EAU
		# 3 = VIDE — géré dans _placer_case(), jamais atteint ici
		4:  return SCENE_CASE_FORET
		5:  return SCENE_CASE_MUR
		6:  return SCENE_CASE_TOUR
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
# Remplace l'ancienne version 2D (calcul mathématique sur
# une projection isométrique pixel) par un vrai raycast 3D.
#
# Principe :
#   1. On projette un rayon depuis la caméra à travers
#      le pixel cliqué (camera.project_ray_origin/direction)
#   2. Ce rayon intersecte un plan horizontal y=0 (le sol)
#   3. Le point d'intersection donne une position 3D
#   4. On inverse grid_to_world() pour obtenir (grid_x, grid_y)
#   5. On vérifie que la case est dans les bornes du plateau
#
# Retourne Vector2i(-1, -1) si le clic est hors plateau.
# =======================================================
func screen_to_grid(pos: Vector2) -> Vector2i:
	# Sécurité — si la caméra n'est pas encore injectée
	if camera == null:
		push_warning("renderer.screen_to_grid() — camera est null !")
		return Vector2i(-1, -1)

	# Étape 1 — Récupère l'origine et la direction du rayon
	# project_ray_origin : point de départ du rayon (position caméra)
	# project_ray_normal : direction normalisée vers le pixel cliqué
	var origine   : Vector3 = camera.project_ray_origin(pos)
	var direction : Vector3 = camera.project_ray_normal(pos)

	# Étape 2 — Intersection rayon / plan horizontal y=0
	# On cherche t tel que : origine.y + t * direction.y = 0
	# → t = -origine.y / direction.y
	# Si direction.y == 0, le rayon est parallèle au sol → pas d'intersection
	if abs(direction.y) < 0.001:
		return Vector2i(-1, -1)

	var t         : float   = -origine.y / direction.y
	var point_sol : Vector3 = origine + direction * t

	# Étape 3 — Conversion position 3D → coordonnées de grille
	# On inverse grid_to_world() :
	#   grid_to_world(x, y) = OFFSET_PLATEAU + Vector3(x * CASE_SIZE, 0, y * CASE_SIZE)
	# Donc : x = (point_sol.x - OFFSET_PLATEAU.x) / CASE_SIZE
	var gx : int = roundi((point_sol.x - OFFSET_PLATEAU.x) / CASE_SIZE)
	var gy : int = roundi((point_sol.z - OFFSET_PLATEAU.z) / CASE_SIZE)

	# Étape 4 — Vérifie que la case est dans les bornes du plateau 8x8
	if gx < 0 or gx >= TAILLE_PLATEAU or gy < 0 or gy >= TAILLE_PLATEAU:
		return Vector2i(-1, -1)

	return Vector2i(gx, gy)


# -------------------------------------------------------
# Calcule toutes les cases réellement atteignables depuis
# la position (jx, jy) avec pm_disponibles PM.
#
# Utilise un BFS (Breadth-First Search) qui explore les cases
# adjacentes une par une — simule le déplacement case par case.
#
# Un MUR ou VIDE sur le chemin bloque TOUTES les cases derrière.
# Une case Forêt coûte 2 PM au lieu de 1.
# Les cases occupées ne sont pas atteignables mais ne bloquent
# PAS le chemin — on peut longer un joueur sans passer dessus.
#
# Retourne un dictionnaire "x,y" → coût PM pour y arriver.
# -------------------------------------------------------
func _calculer_cases_accessibles(jx: int, jy: int, pm_disponibles: int) -> Dictionary:
	# Dictionnaire des cases atteignables : "x,y" → coût PM pour y arriver
	var atteignables : Dictionary = {}

	# File BFS : chaque entrée est [x, y, pm_consommes]
	var file : Array = [[jx, jy, 0]]

	# Cases déjà visitées pour éviter les boucles
	var visites : Dictionary = {}
	visites["%d,%d" % [jx, jy]] = true

	# Directions cardinales (haut, bas, gauche, droite)
	# Pas de diagonales — déplacement case par case
	const DIRECTIONS : Array = [
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

			# Hors plateau
			if nx < 0 or nx >= TAILLE_PLATEAU or ny < 0 or ny >= TAILLE_PLATEAU:
				continue

			# Déjà visité avec un coût inférieur ou égal
			if visites.has(cle):
				continue

			var type_case : int = board.get_case(nx, ny)

			# Cases infranchissables — bloquent le chemin
			if type_case == 3 or type_case == 5:  # VIDE ou MUR
				continue

			# Coût pour entrer dans cette case
			# Forêt = 2 PM, toutes les autres = 1 PM
			var cout : int = 2 if type_case == 4 else 1  # 4 = FORET

			var nouveau_pm : int = pm_used + cout

			# Dépasse les PM disponibles
			if nouveau_pm > pm_disponibles:
				continue

			# Marque comme visité
			visites[cle] = true

			# Case occupée par un joueur : on peut longer mais pas s'arrêter.
			# On l'ajoute à la file pour continuer l'exploration,
			# mais PAS dans atteignables (on ne peut pas s'y arrêter).
			if board.case_occupee(nx, ny):
				file.append([nx, ny, nouveau_pm])
				continue

			# Case atteignable et libre
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
# Appelée depuis rafraichir().
# -------------------------------------------------------
func _mettre_a_jour_joueurs() -> void:
	for i in range(joueurs.size()):
		var joueur : Node = joueurs[i]
		var cle    : String = str(i)

		# Cas 1 — Joueur mort ou non placé : on supprime son pion s'il existe
		if joueur.est_mort or not joueur.est_place:
			if _noeuds_joueurs.has(cle):
				_noeuds_joueurs[cle].queue_free()
				_noeuds_joueurs.erase(cle)
			continue

		# Cas 2 — Joueur vivant et placé
		if not _noeuds_joueurs.has(cle):
			# Premier affichage : on crée le pion complet (pion + accessoires)
			var noeud_pion : Node3D = _creer_pion(joueur)
			add_child(noeud_pion)
			_noeuds_joueurs[cle] = noeud_pion

		# Dans tous les cas, on synchronise la position 3D avec la grille
		# Y = 0.1 pour poser le pion légèrement au-dessus de la case
		var pos_monde : Vector3 = grid_to_world(joueur.grid_x, joueur.grid_y)
		_noeuds_joueurs[cle].position = Vector3(pos_monde.x, 0.1, pos_monde.z)


# -------------------------------------------------------
# Crée un Node3D parent contenant le pion + ses accessoires.
#
# Architecture :
#   Node3D (racine_pion)
#   ├── pion_blanc  ← corps du pion
#   ├── hache       ← accessoire 1 (selon classe)
#   └── bouclier    ← accessoire 2 (selon classe)
#
# Les accessoires sont positionnés relativement au pion
# grâce à une position locale (pas mondiale).
# -------------------------------------------------------
# -------------------------------------------------------
# Crée le pion 3D complet pour un joueur selon sa classe.
# Chaque classe a son propre .glb avec pion + accessoires
# déjà positionnés correctement depuis Blender.
# Plus besoin de positionner les accessoires en code.
# -------------------------------------------------------
func _creer_pion(joueur: Node) -> Node3D:
	var scene : PackedScene = _get_scene_pion(joueur)
	var noeud : Node3D      = scene.instantiate()
	return noeud


# -------------------------------------------------------
# Retourne la scène du pion selon la classe du joueur.
# Détection via resource_path (même logique que input_handler).
# -------------------------------------------------------
func _get_scene_pion(joueur: Node) -> PackedScene:
	var chemin : String = joueur.get_script().resource_path.to_lower()
	if "guerrier" in chemin: return SCENE_PION_GUERRIER
	if "mage"     in chemin: return SCENE_PION_MAGE
	if "archer"   in chemin: return SCENE_PION_ARCHER
	if "fripon"   in chemin: return SCENE_PION_FRIPON
	# Fallback si classe non reconnue
	push_warning("renderer._get_scene_pion() — classe inconnue : %s" % chemin)
	return SCENE_PION_GUERRIER


# =======================================================
# SURBRILLANCES — Plans transparents au-dessus des cases
# =======================================================

# -------------------------------------------------------
# Supprime toutes les surbrillances existantes et recrée
# celles qui correspondent à l'état de sélection actuel.
#
# Appelée depuis rafraichir() après _mettre_a_jour_cases().
# Si aucun joueur n'est sélectionné, on supprime tout et on sort.
# -------------------------------------------------------
func _mettre_a_jour_surbrillances() -> void:
	# Supprime toutes les surbrillances de l'appel précédent
	for noeud in _noeuds_surbrillances:
		noeud.queue_free()
	_noeuds_surbrillances.clear()

	# Rien à afficher si pas de joueur sélectionné
	if not joueur_selectionne or joueur_actif == null:
		return

	# Si un sort est sélectionné → UNIQUEMENT le violet, pas le jaune/rouge
	if sort_selectionne >= 0 and sort_selectionne < joueur_actif.sorts.size():
		_afficher_surbrillance_sort()
	else:
		# Pas de sort sélectionné → déplacement jaune + attaque rouge
		_afficher_surbrillance_deplacement()
		_afficher_surbrillance_attaque()


# -------------------------------------------------------
# Surbrillance jaune — cases accessibles en déplacement.
# Utilise le BFS pour ne montrer que les cases vraiment
# atteignables (obstacles et coût forêt pris en compte).
# -------------------------------------------------------
func _afficher_surbrillance_deplacement() -> void:
	# BFS depuis la position du joueur avec ses PM restants
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
			_creer_surbrillance(ennemi.grid_x, ennemi.grid_y, Color(1.0, 0.2, 0.2, 0.45))  # Rouge


# -------------------------------------------------------
# Surbrillance violette — portée du sort actuellement sélectionné.
# -------------------------------------------------------
func _afficher_surbrillance_sort() -> void:
	var sort   : Resource = joueur_actif.sorts[sort_selectionne]
	var portee : int      = sort.portee
	var jx     : int      = joueur_actif.grid_x
	var jy     : int      = joueur_actif.grid_y

	# Portée 0 = portée illimitée (Tempête Arcanique) → tout le plateau
	for x in range(8):
		for y in range(8):
			if x == jx and y == jy:
				continue
			var dist : int = abs(x - jx) + abs(y - jy)
			if portee == 0 or dist <= portee:
				_creer_surbrillance(x, y, Color(0.7, 0.2, 1.0, 0.45))  # Violet


# -------------------------------------------------------
# Crée un plan plat transparent (MeshInstance3D) sur la case (x, y).
#
# PlaneMesh est un plan horizontal dans Godot (axes X et Z).
# On le place à HAUTEUR_SURBRILLANCE pour qu'il flotte
# légèrement au-dessus de la surface des cases .glb.
#
# Le matériau est en TRANSPARENCY_ALPHA pour afficher
# la transparence correctement sans artefacts.
# -------------------------------------------------------
func _creer_surbrillance(x: int, y: int, couleur: Color) -> void:
	var mesh_instance := MeshInstance3D.new()

	# Crée un plan plat aux dimensions de la surbrillance
	var plan := PlaneMesh.new()
	plan.size = Vector2(TAILLE_SURBRILLANCE, TAILLE_SURBRILLANCE)
	mesh_instance.mesh = plan

	# Matériau transparent avec la couleur voulue
	var mat := StandardMaterial3D.new()
	mat.albedo_color            = couleur
	mat.transparency            = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode            = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

	# Position : centre de la case + légèrement en hauteur
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
# Même stratégie que les surbrillances : on reconstruit tout
# à chaque rafraichir() car les événements changent peu souvent.
# -------------------------------------------------------
func _mettre_a_jour_evenements() -> void:
	if event_manager == null:
		return

	# Supprime tous les nœuds existants
	for noeud in _noeuds_evenements.values():
		noeud.queue_free()
	_noeuds_evenements.clear()

	# Mines actives — charriot.glb posé sur la case
	for mine in event_manager.mines_actives:
		_placer_evenement(
			mine["x"], mine["y"],
			SCENE_MINE,
			"mine_%d_%d" % [mine["x"], mine["y"]],
			0.57  # Légèrement au-dessus de la case
		)

	# Tas de pièces — après destruction d'une mine
	for tas in event_manager.tas_pieces_actifs:
		_placer_evenement(
			tas["x"], tas["y"],
			SCENE_TAS_PIECES,
			"tas_%d_%d" % [tas["x"], tas["y"]],
			0.15
		)

	# Coffres au trésor
	for coffre in event_manager.coffres_actifs:
		_placer_evenement(
			coffre["x"], coffre["y"],
			SCENE_COFFRE,
			"coffre_%d_%d" % [coffre["x"], coffre["y"]],
			0.35
		)


# -------------------------------------------------------
# Instancie un .glb d'événement et le positionne sur la case (x, y).
# hauteur_y : décalage vertical pour poser l'objet sur la case
#             sans le faire traverser (0.1 = 10cm au-dessus)
# -------------------------------------------------------
func _placer_evenement(x: int, y: int, scene: PackedScene, cle: String, hauteur_y: float) -> void:
	var noeud : Node3D = scene.instantiate()
	var pos   : Vector3 = grid_to_world(x, y)
	noeud.position = Vector3(pos.x, hauteur_y, pos.z)
	add_child(noeud)

	# Barre de vie uniquement pour les mines
	if cle.begins_with("mine_"):
		# Cherche les HP de cette mine dans event_manager
		for mine in event_manager.mines_actives:
			if mine["x"] == x and mine["y"] == y:
				var label := Label3D.new()
				label.name      = "BarreVie"
				label.position  = Vector3(0.0, 0.9, 0.0)  # Au-dessus de la mine
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Toujours face à la caméra
				label.font_size = 28
				label.modulate  = Color(0.1, 0.9, 0.1)  # Vert
				label.text      = "❤️ %d / %d" % [mine["hp"], mine["hp_max"]]
				noeud.add_child(label)
				break

	_noeuds_evenements[cle] = noeud
