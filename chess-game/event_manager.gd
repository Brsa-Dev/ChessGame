# event_manager.gd
# -----------------------------------------------
# EVENT MANAGER — Gestion des événements du plateau
# Branché sur tour_global_termine depuis main.gd
# Déclenche un événement ALÉATOIRE tous les 4 tours globaux
# Anti-répétition : le même event ne se déclenche pas 2 fois de suite
# -----------------------------------------------
extends Node

# -----------------------------------------------
# CONSTANTES
# -----------------------------------------------

# Liste de tous les événements disponibles
# Pour ajouter un nouvel event : ajouter son nom ici
# + créer sa fonction _spawner_xxx() + le brancher dans verifier_tour()
const EVENEMENTS_DISPONIBLES = ["mine_or", "coffre", "tempete", "inondation"]

# HP des mines d'or
const MINE_HP_MAX = 30

# Gold donné par un tas de pièces (mine détruite)
const MINE_GOLD_REWARD = 5

# Gold donné par un coffre
const COFFRE_GOLD_REWARD = 10

# Nombre de mines à spawner
const MINES_PAR_EVENT = 3

# Nombre de cases inondées
const CASES_INONDEES = 4

# Durée de l'inondation en tours globaux
const INONDATION_DUREE = 3

# -----------------------------------------------
# ÉTAT INTERNE
# -----------------------------------------------

# Dernier événement déclenché — pour l'anti-répétition
var dernier_evenement: String = ""

# Référence au board — assignée par main.gd dans _ready()
var board: Node = null

# -----------------------------------------------
# MINES D'OR ACTIVES
# Format : { "x": int, "y": int, "hp": int, "hp_max": int }
# -----------------------------------------------
var mines_actives: Array = []

# -----------------------------------------------
# TAS DE PIÈCES ACTIFS
# Laissés par une mine détruite, ramassés en marchant dessus
# Format : { "x": int, "y": int, "gold": int }
# -----------------------------------------------
var tas_pieces_actifs: Array = []

# -----------------------------------------------
# COFFRES AU TRÉSOR ACTIFS
# Format : { "x": int, "y": int, "gold": int }
# -----------------------------------------------
var coffres_actifs: Array = []

# -----------------------------------------------
# INONDATIONS ACTIVES
# Format : { "cases": [{"x", "y", "type_original"}], "tours_restants": int }
# -----------------------------------------------
var inondations_actives: Array = []

# -----------------------------------------------
# SIGNAUX — écoutés par main.gd
# -----------------------------------------------
signal evenement_declenche(nom: String)  # Nom de l'event déclenché
signal mine_detruite(x: int, y: int)     # Position de la mine détruite
signal piece_ramassee(joueur: Node, gold: int)
signal coffre_ramasse(joueur: Node, gold: int)

# -----------------------------------------------
# verifier_tour — Appelée par main.gd à chaque
# signal tour_global_termine.
# Déclenche un event aléatoire tous les 4 tours.
# -----------------------------------------------
func verifier_tour(numero_tour: int):
	# Un événement tous les 4 tours globaux uniquement
	if numero_tour % 4 != 0:
		return

	# Construit la liste des événements éligibles
	# → exclut le dernier event déclenché (anti-répétition)
	var eligibles = EVENEMENTS_DISPONIBLES.filter(
		func(e): return e != dernier_evenement
	)

	# Sécurité : si un seul event dans la liste, on ignore l'anti-répétition
	if eligibles.is_empty():
		eligibles = EVENEMENTS_DISPONIBLES.duplicate()

	# Tirage aléatoire parmi les éligibles
	eligibles.shuffle()
	var choix = eligibles[0]
	dernier_evenement = choix

	print("🎲 Événement du tour ", numero_tour, " : ", choix)

	# Déclenche l'événement correspondant
	match choix:
		"mine_or":    _spawner_mines()
		"coffre":     _spawner_coffre()
		"tempete":    _spawner_tempete()
		"inondation": _spawner_inondation()

# ===============================================
# SPAWNERS — un par type d'événement
# ===============================================

# -----------------------------------------------
# _spawner_mines — Fait apparaître 3 mines d'or
# sur des cases libres aléatoires.
# Exclut LAVE, VIDE, MUR, cases avec déjà une mine/coffre.
# -----------------------------------------------
func _spawner_mines():
	var cases_libres = _get_cases_libres()
	cases_libres.shuffle()

	var nb_spawns = min(MINES_PAR_EVENT, cases_libres.size())
	for i in range(nb_spawns):
		var pos = cases_libres[i]
		mines_actives.append({
			"x":      pos.x,
			"y":      pos.y,
			"hp":     MINE_HP_MAX,
			"hp_max": MINE_HP_MAX
		})
		print("⛏️ Mine d'Or apparue en (", pos.x, ",", pos.y, ")")

	emit_signal("evenement_declenche", "mine_or")

# -----------------------------------------------
# _spawner_coffre — Fait apparaître 1 coffre
# sur une case libre aléatoire.
# -----------------------------------------------
func _spawner_coffre():
	var cases_libres = _get_cases_libres()
	if cases_libres.is_empty():
		print("⚠️ Aucune case libre pour le coffre !")
		return

	cases_libres.shuffle()
	var pos = cases_libres[0]
	coffres_actifs.append({
		"x":    pos.x,
		"y":    pos.y,
		"gold": COFFRE_GOLD_REWARD
	})
	print("💎 Coffre au Trésor apparu en (", pos.x, ",", pos.y, ")")
	emit_signal("evenement_declenche", "coffre")

# -----------------------------------------------
# _spawner_tempete — Tempête Électrique
# La déduction réelle des PM est faite dans main.gd
# via le signal evenement_declenche("tempete")
# -----------------------------------------------
func _spawner_tempete():
	print("⚡ Tempête Électrique ! Tous les joueurs perdent 1 PM")
	emit_signal("evenement_declenche", "tempete")

# -----------------------------------------------
# _spawner_inondation — 4 cases aléatoires → Eau
# pendant INONDATION_DUREE tours globaux.
# On mémorise le type original pour restauration.
# Inclut les cases occupées par des joueurs
# (l'effet Eau s'applique immédiatement via main.gd)
# -----------------------------------------------
func _spawner_inondation():
	var cases_eligibles = _get_cases_libres_inondation()
	cases_eligibles.shuffle()

	var nb = min(CASES_INONDEES, cases_eligibles.size())
	var cases_transformees = []

	for i in range(nb):
		var pos = cases_eligibles[i]
		cases_transformees.append({
			"x":             pos.x,
			"y":             pos.y,
			"type_original": board.get_case(pos.x, pos.y)
		})
		board.plateau[pos.x][pos.y] = board.CaseType.EAU
		print("🌊 Inondation en (", pos.x, ",", pos.y, ")")

	inondations_actives.append({
		"cases":          cases_transformees,
		"tours_restants": INONDATION_DUREE
	})

	emit_signal("evenement_declenche", "inondation")

# ===============================================
# ACTIONS EN JEU — appelées depuis main.gd
# ===============================================

# -----------------------------------------------
# attaquer_mine — Inflige des dégâts à la mine
# en (x, y). Appelée par main.gd pour l'attaque
# de base ET les sorts offensifs.
# Retourne les dégâts infligés (0 si pas de mine).
# -----------------------------------------------
func attaquer_mine(x: int, y: int, degats: int, attaquant: Node) -> int:
	for mine in mines_actives:
		if mine["x"] == x and mine["y"] == y:
			mine["hp"] -= degats
			mine["hp"] = max(0, mine["hp"])
			print("⛏️ Mine touchée ! HP : ", mine["hp"], "/", mine["hp_max"])

			if mine["hp"] <= 0:
				_detruire_mine(mine, attaquant)
			return degats

	return 0  # Aucune mine à cette position

# -----------------------------------------------
# _detruire_mine — Mine à 0 HP
# → la retire et laisse un tas de pièces
# -----------------------------------------------
func _detruire_mine(mine: Dictionary, _attaquant: Node):
	mines_actives.erase(mine)

	# Laisse un tas de pièces à ramasser sur la case
	tas_pieces_actifs.append({
		"x":    mine["x"],
		"y":    mine["y"],
		"gold": MINE_GOLD_REWARD
	})
	print("💰 Mine détruite ! Tas de pièces en (", mine["x"], ",", mine["y"], ")")
	emit_signal("mine_detruite", mine["x"], mine["y"])

# -----------------------------------------------
# verifier_ramassage — Appelée depuis main.gd
# après chaque déplacement d'un joueur.
# Vérifie si le joueur marche sur un tas ou un coffre.
# -----------------------------------------------
func verifier_ramassage(joueur: Node):
	# --- Tas de pièces ---
	var tas_a_supprimer = []
	for tas in tas_pieces_actifs:
		if tas["x"] == joueur.grid_x and tas["y"] == joueur.grid_y:
			joueur.gold += tas["gold"]
			tas_a_supprimer.append(tas)
			print("💰 ", joueur.name, " ramasse un tas ! +", tas["gold"], " Gold")
			emit_signal("piece_ramassee", joueur, tas["gold"])
	for tas in tas_a_supprimer:
		tas_pieces_actifs.erase(tas)

	# --- Coffres ---
	var coffres_a_supprimer = []
	for coffre in coffres_actifs:
		if coffre["x"] == joueur.grid_x and coffre["y"] == joueur.grid_y:
			joueur.gold += coffre["gold"]
			coffres_a_supprimer.append(coffre)
			print("💎 ", joueur.name, " ouvre un coffre ! +", coffre["gold"], " Gold")
			emit_signal("coffre_ramasse", joueur, coffre["gold"])
	for coffre in coffres_a_supprimer:
		coffres_actifs.erase(coffre)

# -----------------------------------------------
# reduire_inondations — Appelée depuis main.gd
# dans _on_tour_global_termine().
# Décrémente les tours restants et restaure
# les cases expirées.
# Retourne la liste des cases restaurées.
# -----------------------------------------------
func reduire_inondations() -> Array:
	var restaurees = []
	var a_supprimer = []

	for inondation in inondations_actives:
		inondation["tours_restants"] -= 1
		print("🌊 Inondation — ", inondation["tours_restants"], " tour(s) restant(s)")

		if inondation["tours_restants"] <= 0:
			for case_info in inondation["cases"]:
				board.plateau[case_info["x"]][case_info["y"]] = case_info["type_original"]
				restaurees.append(case_info)
				print("🍂 Restaurée : (", case_info["x"], ",", case_info["y"], ")")
			a_supprimer.append(inondation)

	for inondation in a_supprimer:
		inondations_actives.erase(inondation)

	return restaurees

# ===============================================
# HELPERS — utilitaires internes
# ===============================================

# -----------------------------------------------
# get_mine_en — Retourne la mine en (x,y) ou {}
# Utilisée par main.gd pour détecter le clic sur mine
# et par renderer.gd pour la surbrillance
# -----------------------------------------------
func get_mine_en(x: int, y: int) -> Dictionary:
	for mine in mines_actives:
		if mine["x"] == x and mine["y"] == y:
			return mine
	return {}

# -----------------------------------------------
# _get_cases_libres — Cases éligibles pour spawn
# mines et coffres.
# Exclut : LAVE, VIDE, MUR, cases occupées,
# cases avec déjà une mine ou un coffre.
# -----------------------------------------------
func _get_cases_libres() -> Array:
	var libres = []
	for x in range(8):
		for y in range(8):
			var type_case = board.get_case(x, y)
			if type_case == board.CaseType.VIDE \
			or type_case == board.CaseType.MUR  \
			or type_case == board.CaseType.LAVE:
				continue
			if board.case_occupee(x, y):
				continue
			# Pas déjà une mine ici
			if get_mine_en(x, y) != {}:
				continue
			# Pas déjà un coffre ici
			var coffre_present = false
			for coffre in coffres_actifs:
				if coffre["x"] == x and coffre["y"] == y:
					coffre_present = true
					break
			if coffre_present:
				continue
			libres.append(Vector2i(x, y))
	return libres

# -----------------------------------------------
# _get_cases_libres_inondation — Cases éligibles
# pour l'inondation.
# Plus permissif que _get_cases_libres :
# inclut les cases occupées par des joueurs
# (ils recevront l'effet Eau immédiatement).
# Exclut : LAVE, VIDE, MUR, TOUR, EAU (déjà inondée)
# -----------------------------------------------
func _get_cases_libres_inondation() -> Array:
	var libres = []
	for x in range(8):
		for y in range(8):
			var type_case = board.get_case(x, y)
			if type_case == board.CaseType.VIDE  \
			or type_case == board.CaseType.MUR   \
			or type_case == board.CaseType.LAVE  \
			or type_case == board.CaseType.TOUR  \
			or type_case == board.CaseType.EAU:
				continue
			libres.append(Vector2i(x, y))
	return libres
