# =======================================================
# Manager/event_manager.gd
# -------------------------------------------------------
# Gestion des événements aléatoires du plateau.
#
#   - Déclenche un événement tous les 4 tours globaux
#   - Anti-répétition : jamais 2× le même événement de suite
#   - 4 événements : Mines d'Or, Coffre, Tempête, Inondation
#
# Branché sur tour_global_termine depuis main.gd.
# Architecture extensible : ajouter un event = 1 entrée dans
# EVENEMENTS_DISPONIBLES + 1 fonction _spawner_xxx().
# =======================================================
extends Node


# =======================================================
# SIGNAUX
# =======================================================

signal evenement_declenche(nom: String)       # Écouté par main.gd pour les logs et effets
signal mine_detruite(x: int, y: int)          # Disponible pour extensions
signal piece_ramassee(joueur: Node, gold: int)
signal coffre_ramasse(joueur: Node, gold: int)


# =======================================================
# CONSTANTES — Événements
# =======================================================

const EVENEMENTS_DISPONIBLES : Array[String] = ["mine_or", "coffre", "tempete", "inondation"]
const FREQUENCE_EVENEMENT    : int           = 4   # Tours globaux entre chaque événement


# =======================================================
# CONSTANTES — Mines d'Or
# =======================================================

const MINE_HP_MAX      : int = 30  # HP d'une mine au spawn
const MINE_GOLD_REWARD : int = 5   # Gold laissé par un tas de pièces
const MINES_PAR_EVENT  : int = 3   # Mines spawnées par événement


# =======================================================
# CONSTANTES — Coffre
# =======================================================

const COFFRE_GOLD_REWARD : int = 10  # Gold donné par un coffre


# =======================================================
# CONSTANTES — Inondation
# =======================================================

const INONDATION_NB_CASES : int = 4  # Cases transformées en Eau
const INONDATION_DUREE    : int = 3  # Tours globaux avant restauration


# =======================================================
# RÉFÉRENCES
# =======================================================

var board : Node = null  # Injecté par main.gd — pour lire et modifier le plateau


# =======================================================
# ÉTAT — Événements actifs
# =======================================================

# Dernier événement déclenché — exclu du prochain tirage (anti-répétition)
var dernier_evenement : String = ""

# Mines d'Or actives sur le plateau
# Format : { "x": int, "y": int, "hp": int, "hp_max": int }
var mines_actives : Array = []

# Tas de pièces laissés par des mines détruites — ramassés en marchant dessus
# Format : { "x": int, "y": int, "gold": int }
var tas_pieces_actifs : Array = []

# Coffres au Trésor actifs
# Format : { "x": int, "y": int, "gold": int }
var coffres_actifs : Array = []

# Inondations actives — cases temporairement transformées en Eau
# Format : { "cases": [{"x", "y", "type_original"}], "tours_restants": int }
var inondations_actives : Array = []


# =======================================================
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Appelée par main.gd à chaque signal tour_global_termine.
# Déclenche un événement tous les FREQUENCE_EVENEMENT tours.
# -------------------------------------------------------
func verifier_tour(numero_tour: int) -> void:
	if numero_tour % FREQUENCE_EVENEMENT != 0:
		return

	# Exclut le dernier événement pour éviter la répétition
	var eligibles : Array[String] = EVENEMENTS_DISPONIBLES.filter(
		func(e: String) -> bool: return e != dernier_evenement
	)

	# Sécurité si un seul événement dans la liste
	if eligibles.is_empty():
		eligibles = EVENEMENTS_DISPONIBLES.duplicate()

	eligibles.shuffle()
	var choix : String = eligibles[0]
	dernier_evenement  = choix

	match choix:
		"mine_or":    _spawner_mines()
		"coffre":     _spawner_coffre()
		"tempete":    _spawner_tempete()
		"inondation": _spawner_inondation()


# -------------------------------------------------------
# Inflige des dégâts à la mine en (x, y).
# Appelée depuis main.gd et sort_handler pour les attaques offensives.
# Retourne les dégâts réellement infligés (0 si pas de mine).
# -------------------------------------------------------
func attaquer_mine(x: int, y: int, degats: int, attaquant: Node) -> int:
	for mine in mines_actives:
		if mine["x"] != x or mine["y"] != y:
			continue

		mine["hp"] = max(0, mine["hp"] - degats)

		if mine["hp"] <= 0:
			_detruire_mine(mine, attaquant)

		return degats

	return 0  # Aucune mine à cette position


# -------------------------------------------------------
# Vérifie si le joueur vient de marcher sur un tas de pièces
# ou un coffre. Appelée par input_handler après chaque déplacement.
# -------------------------------------------------------
func verifier_ramassage(joueur: Node) -> void:
	# Tas de pièces
	var tas_a_supprimer : Array[Dictionary] = []
	for tas in tas_pieces_actifs:
		if tas["x"] == joueur.grid_x and tas["y"] == joueur.grid_y:
			joueur.gold += tas["gold"]
			tas_a_supprimer.append(tas)
			piece_ramassee.emit(joueur, tas["gold"])
	for tas in tas_a_supprimer:
		tas_pieces_actifs.erase(tas)

	# Coffres
	var coffres_a_supprimer : Array[Dictionary] = []
	for coffre in coffres_actifs:
		if coffre["x"] == joueur.grid_x and coffre["y"] == joueur.grid_y:
			joueur.gold += coffre["gold"]
			coffres_a_supprimer.append(coffre)
			coffre_ramasse.emit(joueur, coffre["gold"])
	for coffre in coffres_a_supprimer:
		coffres_actifs.erase(coffre)


# -------------------------------------------------------
# Décrémente les inondations actives et restaure les cases expirées.
# Appelée dans main._on_tour_global_termine().
# Retourne la liste des cases restaurées (pour re-appliquer les effets).
# -------------------------------------------------------
func reduire_inondations() -> Array[Dictionary]:
	var restaurees  : Array[Dictionary] = []
	var a_supprimer : Array[Dictionary] = []

	for inondation in inondations_actives:
		inondation["tours_restants"] -= 1

		if inondation["tours_restants"] <= 0:
			for case_info in inondation["cases"]:
				board.plateau[case_info["x"]][case_info["y"]] = case_info["type_original"]
				restaurees.append(case_info)
			a_supprimer.append(inondation)

	for inondation in a_supprimer:
		inondations_actives.erase(inondation)

	return restaurees


# -------------------------------------------------------
# Retourne la mine en (x, y) ou un dict vide {}.
# Utilisée par sort_handler pour détecter une mine cible.
# -------------------------------------------------------
func get_mine_en(x: int, y: int) -> Dictionary:
	for mine in mines_actives:
		if mine["x"] == x and mine["y"] == y:
			return mine
	return {}


# =======================================================
# SPAWNERS
# =======================================================

# -------------------------------------------------------
# Fait apparaître MINES_PAR_EVENT mines sur des cases libres.
# Exclut LAVE, VIDE, MUR et les cases déjà occupées.
# -------------------------------------------------------
func _spawner_mines() -> void:
	var cases_libres : Array[Vector2i] = _get_cases_libres()
	cases_libres.shuffle()

	var nb : int = min(MINES_PAR_EVENT, cases_libres.size())
	for i in range(nb):
		var pos : Vector2i = cases_libres[i]
		mines_actives.append({
			"x"      : pos.x,
			"y"      : pos.y,
			"hp"     : MINE_HP_MAX,
			"hp_max" : MINE_HP_MAX
		})

	evenement_declenche.emit("mine_or")


# -------------------------------------------------------
# Fait apparaître 1 coffre sur une case libre.
# -------------------------------------------------------
func _spawner_coffre() -> void:
	var cases_libres : Array[Vector2i] = _get_cases_libres()
	if cases_libres.is_empty():
		push_warning("event_manager._spawner_coffre() — aucune case libre pour le coffre !")
		return

	cases_libres.shuffle()
	var pos : Vector2i = cases_libres[0]
	coffres_actifs.append({
		"x"    : pos.x,
		"y"    : pos.y,
		"gold" : COFFRE_GOLD_REWARD
	})
	evenement_declenche.emit("coffre")


# -------------------------------------------------------
# Tempête Électrique — la logique de malus PM est dans main.gd
# via le signal evenement_declenche("tempete").
# -------------------------------------------------------
func _spawner_tempete() -> void:
	evenement_declenche.emit("tempete")


# -------------------------------------------------------
# Transforme INONDATION_NB_CASES cases aléatoires en Eau.
# Les joueurs dessus reçoivent l'effet Eau via main.gd.
# Les cases sont restaurées après INONDATION_DUREE tours globaux.
# -------------------------------------------------------
func _spawner_inondation() -> void:
	var eligibles : Array[Vector2i] = _get_cases_libres_inondation()
	eligibles.shuffle()

	var nb                 : int              = min(INONDATION_NB_CASES, eligibles.size())
	var cases_transformees : Array[Dictionary] = []

	for i in range(nb):
		var pos : Vector2i = eligibles[i]
		cases_transformees.append({
			"x"            : pos.x,
			"y"            : pos.y,
			"type_original": board.get_case(pos.x, pos.y)
		})
		board.plateau[pos.x][pos.y] = board.CaseType.EAU

	inondations_actives.append({
		"cases"          : cases_transformees,
		"tours_restants" : INONDATION_DUREE
	})

	evenement_declenche.emit("inondation")


# -------------------------------------------------------
# Mine détruite : remplacée par un tas de pièces ramassable.
# -------------------------------------------------------
func _detruire_mine(mine: Dictionary, _attaquant: Node) -> void:
	mines_actives.erase(mine)
	tas_pieces_actifs.append({
		"x"    : mine["x"],
		"y"    : mine["y"],
		"gold" : MINE_GOLD_REWARD
	})
	mine_detruite.emit(mine["x"], mine["y"])


# =======================================================
# HELPERS PRIVÉS
# =======================================================

# -------------------------------------------------------
# Cases éligibles pour les mines et les coffres.
# Exclut LAVE, VIDE, MUR, cases occupées, cases avec mine/coffre.
# -------------------------------------------------------
func _get_cases_libres() -> Array[Vector2i]:
	var libres : Array[Vector2i] = []
	for x in range(board.TAILLE_PLATEAU):
		for y in range(board.TAILLE_PLATEAU):
			var type_case : int = board.get_case(x, y)
			if type_case in [board.CaseType.VIDE, board.CaseType.MUR, board.CaseType.LAVE]:
				continue
			if board.case_occupee(x, y):
				continue
			if get_mine_en(x, y) != {}:
				continue
			var coffre_present : bool = false
			for coffre in coffres_actifs:
				if coffre["x"] == x and coffre["y"] == y:
					coffre_present = true
					break
			if coffre_present:
				continue
			libres.append(Vector2i(x, y))
	return libres


# -------------------------------------------------------
# Cases éligibles pour l'inondation.
# Plus permissif que _get_cases_libres :
# inclut les cases occupées par des joueurs (ils reçoivent l'effet Eau).
# Exclut LAVE, VIDE, MUR, TOUR, EAU (déjà inondée).
# -------------------------------------------------------
func _get_cases_libres_inondation() -> Array[Vector2i]:
	var libres : Array[Vector2i] = []
	for x in range(board.TAILLE_PLATEAU):
		for y in range(board.TAILLE_PLATEAU):
			var type_case : int = board.get_case(x, y)
			if type_case in [
				board.CaseType.VIDE,
				board.CaseType.MUR,
				board.CaseType.LAVE,
				board.CaseType.TOUR,
				board.CaseType.EAU
			]:
				continue
			libres.append(Vector2i(x, y))
	return libres
