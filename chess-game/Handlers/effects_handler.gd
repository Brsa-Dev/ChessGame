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

# -------------------------------------------------------
# Constantes — effets des cases
# -------------------------------------------------------
const DEGATS_LAVE           : int   = 10    # HP perdus en arrivant/restant sur lave
const SOIN_EAU              : int   = 10    # HP gagnés en arrivant/restant sur eau
const RESISTANCE_FORET      : float = 0.10  # 10% résistance sur case forêt
const BONUS_RANGE_TOUR      : int   = 1     # +1 portée sorts sur case tour
const COUT_PM_FORET         : int   = 2     # PM consommés pour entrer en forêt

# -------------------------------------------------------
# Constantes — pièges
# -------------------------------------------------------
const DEGATS_PIEGE          : int = 10  # Dégâts infligés au déclenchement du piège
const DUREE_IMMOBILISATION  : int = 1   # Tours d'immobilisation (sans Piège Amélioré)
const DUREE_IMMOBILISATION_AMELIOREE : int = 2  # Tours avec Piège Amélioré

# -------------------------------------------------------
# Références injectées par main.gd
# -------------------------------------------------------
var board         : Node  = null  # Référence à board.gd — types et état des cases
var log_ui        : Node  = null  # Référence au log — pour afficher les messages
var joueurs       : Array = []    # Liste de tous les joueurs [joueur1, joueur2, joueur3]
var renderer      : Node  = null  # Référence au renderer — pour forcer le redraw


# =======================================================
# EFFET D'ARRIVÉE SUR UNE CASE
# Appelée dans main.gd après chaque déplacement ou
# repositionnement (Ruée, Coup de Bouclier, etc.)
# =======================================================
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
			# Case normale — on réinitialise les bonus de case
			_reinitialiser_effets_case(joueur)


# -------------------------------------------------------
# Lave — dégâts immédiats
# -------------------------------------------------------
func _appliquer_effet_lave(joueur: Node) -> void:
	joueur.recevoir_degats(DEGATS_LAVE)
	joueur.resistance_case  = 0.0
	joueur.bonus_range_sorts = 0
	if joueur.has_method("quitter_foret"):
		joueur.quitter_foret()
	print("🔥 Lave ! -%d HP" % DEGATS_LAVE)


# -------------------------------------------------------
# Eau — soin immédiat
# -------------------------------------------------------
func _appliquer_effet_eau(joueur: Node) -> void:
	joueur.hp_actuels = min(joueur.hp_actuels + SOIN_EAU, joueur.hp_max)
	joueur.resistance_case  = 0.0
	joueur.bonus_range_sorts = 0
	if joueur.has_method("quitter_foret"):
		joueur.quitter_foret()
	print("💧 Eau ! +%d HP" % SOIN_EAU)


# -------------------------------------------------------
# Forêt — résistance + passif Archer
# -------------------------------------------------------
func _appliquer_effet_foret(joueur: Node) -> void:
	joueur.resistance_case  = RESISTANCE_FORET
	joueur.bonus_range_sorts = 0
	if joueur.has_method("entrer_foret"):
		joueur.entrer_foret()
	print("🌲 Forêt ! +%.0f%% résistance" % (RESISTANCE_FORET * 100))


# -------------------------------------------------------
# Tour — bonus de portée sorts
# -------------------------------------------------------
func _appliquer_effet_tour(joueur: Node) -> void:
	joueur.bonus_range_sorts = BONUS_RANGE_TOUR
	joueur.resistance_case  = 0.0
	if joueur.has_method("quitter_foret"):
		joueur.quitter_foret()
	print("🏰 Tour ! +%d portée sorts" % BONUS_RANGE_TOUR)


# -------------------------------------------------------
# Réinitialise tous les bonus de case (case normale)
# -------------------------------------------------------
func _reinitialiser_effets_case(joueur: Node) -> void:
	joueur.resistance_case  = 0.0
	joueur.bonus_range_sorts = 0
	if joueur.has_method("quitter_foret"):
		joueur.quitter_foret()


# =======================================================
# EFFETS PERSISTANTS EN FIN DE TOUR
# Appelée dans fin_de_tour() de main.gd pour le joueur
# qui vient de terminer son tour.
# Seuls Lave et Eau ont un effet persistant.
# =======================================================
func appliquer_effets_persistants(joueur: Node) -> void:
	var type_case : int = board.get_case(joueur.grid_x, joueur.grid_y)

	match type_case:
		board.CaseType.LAVE:
			joueur.recevoir_degats(DEGATS_LAVE)
			print("🔥 Lave persistante ! -%d HP" % DEGATS_LAVE)

		board.CaseType.EAU:
			joueur.hp_actuels = min(joueur.hp_actuels + SOIN_EAU, joueur.hp_max)
			print("💧 Eau persistante ! +%d HP" % SOIN_EAU)


# =======================================================
# VÉRIFICATION DES PIÈGES
# Appelée après chaque déplacement dans main.gd.
# Vérifie si le joueur vient de marcher sur un piège
# posé par un ennemi.
# =======================================================
func verifier_pieges(joueur: Node, pieges_actifs: Array) -> void:
	# On collecte les pièges déclenchés séparément
	# pour ne pas modifier la liste pendant l'itération
	var pieges_declenches : Array = []

	for piege in pieges_actifs:
		var est_sur_le_piege   : bool = piege["x"] == joueur.grid_x and piege["y"] == joueur.grid_y
		var est_pose_par_ennemi: bool = piege["poseur"] != joueur

		if est_sur_le_piege and est_pose_par_ennemi:
			_declencher_piege(joueur, piege)
			pieges_declenches.append(piege)

	# Supprime les pièges déclenchés de la liste partagée
	for piege in pieges_declenches:
		pieges_actifs.erase(piege)


# -------------------------------------------------------
# Déclenche un piège — dégâts + immobilisation
# La durée dépend du Piège Amélioré du poseur
# -------------------------------------------------------
func _declencher_piege(joueur: Node, piege: Dictionary) -> void:
	var poseur           : Node = piege["poseur"]
	var a_piege_ameliore : bool = poseur.piege_ameliore_actif
	var duree_immobilisation : int = DUREE_IMMOBILISATION_AMELIOREE if a_piege_ameliore else DUREE_IMMOBILISATION

	joueur.recevoir_degats(DEGATS_PIEGE)
	joueur.tours_immobilise = duree_immobilisation

	var message : String = "🪤 %s déclenche un piège ! %d dmg + immobilisé %d tour(s)" % [
		joueur.name,
		DEGATS_PIEGE,
		duree_immobilisation
	]
	print(message)
	if log_ui:
		log_ui.ajouter(message, log_ui.COULEUR_SYSTEME)


# =======================================================
# RESTAURATION DES CASES TEMPORAIRES
# =======================================================

# -------------------------------------------------------
# Restaure les cases transformées en Lave par le Météore
# Remet le type original (Normal, Eau, Forêt, etc.)
# -------------------------------------------------------
func restaurer_cases_lave(lave: Dictionary) -> void:
	print("✨ Restauration Lave")
	for case_info in lave["cases"]:
		var x : int = case_info["x"]
		var y : int = case_info["y"]
		board.plateau[x][y] = case_info["type_original"]

		# Si un joueur est sur une case restaurée → on réapplique l'effet
		var joueur_sur_case : Node = _get_joueur_en(x, y)
		if joueur_sur_case:
			appliquer_effet_case(joueur_sur_case)

	if renderer:
		renderer.queue_redraw()


# -------------------------------------------------------
# Restaure les cases transformées en Forêt
# par la Pluie de Flèches ou la Cape de Forêt
# -------------------------------------------------------
func restaurer_cases_foret(foret: Dictionary) -> void:
	print("🍂 Restauration Forêts temporaires")
	for case_info in foret["cases"]:
		var x : int = case_info["x"]
		var y : int = case_info["y"]
		board.plateau[x][y] = case_info["type_original"]

		var joueur_sur_case : Node = _get_joueur_en(x, y)
		if joueur_sur_case:
			appliquer_effet_case(joueur_sur_case)

	if renderer:
		renderer.queue_redraw()


# =======================================================
# HELPERS INTERNES
# =======================================================

# -------------------------------------------------------
# Retourne le joueur présent sur la case (x, y)
# Retourne null si la case est vide ou si personne n'est placé
# -------------------------------------------------------
func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in joueurs:
		var est_vivant_et_place : bool = joueur.est_place and not joueur.est_mort
		if est_vivant_et_place and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null
