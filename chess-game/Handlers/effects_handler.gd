# =======================================================
# effects_handler.gd
# -------------------------------------------------------
# Gère tous les effets liés aux cases et aux états :
#   - Effet d'arrivée sur une case (lave, eau, forêt, tour)
#   - Effets persistants en fin de tour
#   - Vérification et déclenchement des pièges
#   - Restauration des cases temporaires (laves, forêts)
#
# Reçoit ses références depuis main.gd dans _ready().
# N'accède JAMAIS directement aux nœuds de la scène.
# =======================================================
extends Node


# =======================================================
# CONSTANTES — Effets des cases
# =======================================================

const DEGATS_LAVE      : int   = 10    # HP perdus en arrivant/restant sur lave
const SOIN_EAU         : int   = 10    # HP gagnés en arrivant/restant sur eau
const RESISTANCE_FORET : float = 0.10  # 10% résistance sur case forêt
const BONUS_RANGE_TOUR : int   = 1     # +1 portée sorts sur case tour
const COUT_PM_FORET    : int   = 2     # PM consommés pour entrer en forêt


# =======================================================
# CONSTANTES — Pièges
# =======================================================

const DEGATS_PIEGE                   : int = 10  # Dégâts infligés au déclenchement
const DUREE_IMMOBILISATION           : int = 1   # Tours d'immobilisation (standard)
const DUREE_IMMOBILISATION_AMELIOREE : int = 2   # Tours avec Piège Amélioré


# =======================================================
# RÉFÉRENCES — Injectées par main.gd
# =======================================================

var board    : Node       = null  # board.gd — types et état des cases
var joueurs  : Array[Node] = []   # Tous les joueurs [joueur1, joueur2, joueur3]
var renderer : Node       = null  # Pour forcer le redraw après restauration
var log_ui   : Node       = null  # LogUI — historique des actions


# =======================================================
# API PUBLIQUE — Effets de case
# =======================================================

# -------------------------------------------------------
# Applique l'effet de la case sur laquelle le joueur vient d'arriver.
# Appelée dans main.gd après chaque déplacement ou repositionnement.
# -------------------------------------------------------
func appliquer_effet_case(joueur: Node) -> void:
	var type_case : int = board.get_case(joueur.grid_x, joueur.grid_y)

	match type_case:
		board.CaseType.LAVE:
			_appliquer_effet_lave(joueur)
		board.CaseType.EAU:
			_appliquer_effet_eau(joueur)
		board.CaseType.FORET:
			_appliquer_effet_foret(joueur)
		board.CaseType.TOUR:
			_appliquer_effet_tour(joueur)
		_:
			# Case normale — réinitialise les bonus de case
			_reinitialiser_effets_case(joueur)


# -------------------------------------------------------
# Applique les effets persistants de la case en fin de tour.
# Seuls Lave et Eau ont un effet persistant.
# Appelée dans fin_de_tour() de main.gd.
# -------------------------------------------------------
func appliquer_effets_persistants(joueur: Node) -> void:
	var type_case : int = board.get_case(joueur.grid_x, joueur.grid_y)

	match type_case:
		board.CaseType.LAVE:
			joueur.recevoir_degats(DEGATS_LAVE)
		board.CaseType.EAU:
			joueur.hp_actuels = min(joueur.hp_actuels + SOIN_EAU, joueur.hp_max)


# =======================================================
# API PUBLIQUE — Pièges
# =======================================================

# -------------------------------------------------------
# Vérifie si le joueur vient de marcher sur un piège ennemi.
# Appelée après chaque déplacement dans main.gd.
# -------------------------------------------------------
func verifier_pieges(joueur: Node, pieges_actifs: Array[Dictionary]) -> void:
	var pieges_declenches : Array[Dictionary] = []

	for piege in pieges_actifs:
		var est_sur_le_piege    : bool = piege["x"] == joueur.grid_x and piege["y"] == joueur.grid_y
		var est_pose_par_ennemi : bool = piege["poseur"] != joueur

		if est_sur_le_piege and est_pose_par_ennemi:
			_declencher_piege(joueur, piege)
			pieges_declenches.append(piege)

	for piege in pieges_declenches:
		pieges_actifs.erase(piege)


# =======================================================
# API PUBLIQUE — Restauration des cases temporaires
# =======================================================

# -------------------------------------------------------
# Restaure les cases transformées en Lave par le Météore.
# Remet le type original (Normal, Eau, Forêt, etc.)
# -------------------------------------------------------
func restaurer_cases_lave(lave: Dictionary) -> void:
	for case_info in lave["cases"]:
		var x : int = case_info["x"]
		var y : int = case_info["y"]
		board.plateau[x][y] = case_info["type_original"]

		var joueur_sur_case : Node = _get_joueur_en(x, y)
		if joueur_sur_case:
			appliquer_effet_case(joueur_sur_case)

	if renderer:
		renderer.rafraichir()


# -------------------------------------------------------
# Restaure les cases transformées en Forêt
# par la Pluie de Flèches ou la Cape de Forêt.
# -------------------------------------------------------
func restaurer_cases_foret(foret: Dictionary) -> void:
	for case_info in foret["cases"]:
		var x : int = case_info["x"]
		var y : int = case_info["y"]
		board.plateau[x][y] = case_info["type_original"]

		var joueur_sur_case : Node = _get_joueur_en(x, y)
		if joueur_sur_case:
			appliquer_effet_case(joueur_sur_case)

	if renderer:
		renderer.rafraichir()


# =======================================================
# HELPERS PRIVÉS
# =======================================================

func _appliquer_effet_lave(joueur: Node) -> void:
	joueur.recevoir_degats(DEGATS_LAVE)
	joueur.resistance_case   = 0.0
	joueur.bonus_range_sorts = 0
	if joueur.has_method("quitter_foret"):
		joueur.quitter_foret()


func _appliquer_effet_eau(joueur: Node) -> void:
	joueur.hp_actuels = min(joueur.hp_actuels + SOIN_EAU, joueur.hp_max)
	joueur.resistance_case   = 0.0
	joueur.bonus_range_sorts = 0
	if joueur.has_method("quitter_foret"):
		joueur.quitter_foret()


func _appliquer_effet_foret(joueur: Node) -> void:
	joueur.resistance_case   = RESISTANCE_FORET
	joueur.bonus_range_sorts = 0
	if joueur.has_method("entrer_foret"):
		joueur.entrer_foret()


func _appliquer_effet_tour(joueur: Node) -> void:
	joueur.bonus_range_sorts = BONUS_RANGE_TOUR
	joueur.resistance_case   = 0.0
	if joueur.has_method("quitter_foret"):
		joueur.quitter_foret()


func _reinitialiser_effets_case(joueur: Node) -> void:
	joueur.resistance_case   = 0.0
	joueur.bonus_range_sorts = 0
	if joueur.has_method("quitter_foret"):
		joueur.quitter_foret()


# -------------------------------------------------------
# Déclenche un piège — dégâts + immobilisation.
# La durée dépend du Piège Amélioré du poseur.
# -------------------------------------------------------
func _declencher_piege(joueur: Node, piege: Dictionary) -> void:
	var poseur               : Node = piege["poseur"]
	var a_piege_ameliore     : bool = poseur.piege_ameliore_actif
	var duree_immobilisation : int  = DUREE_IMMOBILISATION_AMELIOREE if a_piege_ameliore else DUREE_IMMOBILISATION

	joueur.recevoir_degats(DEGATS_PIEGE)
	joueur.tours_immobilise = duree_immobilisation

	_log("🪤 %s déclenche un piège ! %d dmg + immobilisé %d tour(s)" % [
		joueur.name, DEGATS_PIEGE, duree_immobilisation
	], joueur)


# -------------------------------------------------------
# Envoie un message au log de combat si log_ui est disponible.
# -------------------------------------------------------
func _log(message: String, joueur: Node = null) -> void:
	if log_ui == null:
		return
	log_ui.ajouter(message, joueur)


# -------------------------------------------------------
# Retourne le joueur vivant et placé sur la case (x, y).
# Retourne null si la case est vide.
# -------------------------------------------------------
func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in joueurs:
		var est_vivant_et_place : bool = joueur.est_place and not joueur.est_mort
		if est_vivant_et_place and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null
