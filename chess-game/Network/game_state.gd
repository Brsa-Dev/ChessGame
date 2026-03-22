# =======================================================
# Network/game_state.gd
# -------------------------------------------------------
# Responsabilité : sérialiser et désérialiser l'état du jeu.
#
# Utilisé par le Host pour broadcaster l'état après chaque
# action, et par tous les peers pour l'appliquer.
#
# Principe : le Host est la seule source de vérité.
# Le Client reçoit l'état et l'affiche — il ne calcule rien.
#
# Scalable : fonctionne pour N joueurs (2, 4 ou 6).
# =======================================================
extends Node


# =======================================================
# SÉRIALISATION — État complet → Dictionary
# =======================================================

## Capture l'état complet du jeu en un Dictionary transmissible
## via RPC. Appelée par le Host après chaque action.
##
## @param joueurs      : Array[Node] — liste des joueurs actifs
## @param board        : Node        — état du plateau
## @param tour_manager : Node        — gestionnaire de tours
## @return Dictionary sérialisé, envoyable via rpc()
func serialiser(
	joueurs      : Array,
	board        : Node,
	tour_manager : Node
) -> Dictionary:
	## --- Joueurs ---
	var joueurs_data : Array = []
	for i in range(joueurs.size()):
		var j : Node = joueurs[i]
		joueurs_data.append({
			"index"     : i,
			"grid_x"    : j.grid_x,
			"grid_y"    : j.grid_y,
			"est_place" : j.est_place,
			"est_mort"  : j.est_mort,
			"hp"        : j.hp_actuels,
			"hp_max"    : j.hp_max,
			"pm"        : j.pm_actuels,
			"pm_max"    : j.pm_max,
			"gold"      : j.gold,
			"equipe"    : j.equipe,
			"peer_id"   : j.peer_id,
		})

	## --- Plateau ---
	## Inclus pour synchroniser les changements en cours de partie
	## (laves temporaires, murs, forêts, etc.)
	var plateau_data : Array = board.exporter_etat()

	## --- Tour ---
	var joueur_actif  : Node  = tour_manager.get_joueur_actif()
	var index_actif   : int   = joueurs.find(joueur_actif)
	var temps_restant : float = tour_manager._timer.time_left

	return {
		"joueurs"       : joueurs_data,
		"plateau"       : plateau_data,
		"tour_actif"    : index_actif,
		"tour_global"   : tour_manager.tour_global,
		"temps_restant" : temps_restant,
	}


# =======================================================
# DÉSÉRIALISATION — Dictionary → objets locaux
# =======================================================

## Applique un état reçu depuis le réseau sur les objets locaux.
## Appelée par TOUS les peers (Host inclus) après réception.
##
## @param etat    : Dictionary — état reçu du Host
## @param joueurs : Array[Node] — joueurs locaux à mettre à jour
## @param board   : Node        — plateau local à mettre à jour
func deserialiser(
	etat         : Dictionary,
	joueurs      : Array,
	board        : Node,
	tour_manager : Node = null
) -> void:
	## --- Plateau ---
	## Toujours appliqué en premier car les joueurs peuvent
	## être sur des cases dont le type a changé.
	if etat.has("plateau"):
		board.importer_etat(etat["plateau"])

	## --- Joueurs ---
	if etat.has("joueurs"):
		var joueurs_data : Array = etat["joueurs"]
		for data in joueurs_data:
			var index : int = data.get("index", -1)
			if index < 0 or index >= joueurs.size():
				push_warning("GameState.deserialiser : index joueur invalide %d" % index)
				continue
			var j : Node = joueurs[index]
			j.grid_x     = data.get("grid_x",    j.grid_x)
			j.grid_y     = data.get("grid_y",     j.grid_y)
			j.est_place  = data.get("est_place",  j.est_place)
			j.est_mort   = data.get("est_mort",   j.est_mort)
			j.hp_actuels = data.get("hp",         j.hp_actuels)
			j.hp_max     = data.get("hp_max",     j.hp_max)
			j.pm_actuels = data.get("pm",         j.pm_actuels)
			j.pm_max     = data.get("pm_max",     j.pm_max)
			j.gold       = data.get("gold",       j.gold)

	## --- Tour manager ---
	## Synchronise l'index du joueur actif côté Client.
	## Sans ça, _index_joueur_actif reste sur l'ancien tour
	## et le guard réseau dans _traiter_clic_souris() bloque
	## les actions du Client pendant un tour entier.
	if tour_manager != null and etat.has("tour_actif"):
		tour_manager._index_joueur_actif = etat["tour_actif"]
		tour_manager.tour_global         = etat.get("tour_global", tour_manager.tour_global)

	## --- Timer ---
	## Resynchronise le timer côté Client avec le temps restant du Host.
	## Évite le décalage visuel entre les deux instances.
	if tour_manager != null and etat.has("temps_restant"):
		var temps : float = etat.get("temps_restant", 0.0)
		tour_manager._timer.stop()
		tour_manager._timer.wait_time = max(temps, 0.1)
		tour_manager._timer.start()
