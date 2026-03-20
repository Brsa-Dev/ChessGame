# =======================================================
# Handlers/input_handler.gd
# -------------------------------------------------------
# Responsabilité UNIQUE : capturer et router les inputs.
#
#   - Touche F → inventaire
#   - Touches A/Z/E/R → sélection de sort
#   - Clic gauche → placement, sélection, déplacement,
#                   attaque de base, utilisation de sort
#   - Modes spéciaux → ciblage Bombe, ciblage Cape de Forêt
#   - Items actifs → Bandage, Flèches Empoisonnées
#
# NE contient PAS de logique de gameplay.
# Délègue tout à sort_handler et effects_handler.
# =======================================================
extends Node


# =======================================================
# CONSTANTES — Touches clavier
# =======================================================

const TOUCHE_INVENTAIRE : int = KEY_F


# =======================================================
# CONSTANTES — Sorts
# =======================================================

# Identifiant du sort Dérobade — cas spécial (explosion sur marque active)
const ID_SORT_DEROBADE : String = "fripon_derobade"

# Sorts qui s'appliquent sur le lanceur lui-même — aucune cible requise.
# Ils s'activent dès la sélection, sans attendre un clic sur une case.
const SORTS_AUTO_CIBLANTS : Array[String] = [
	"guerrier_rage",
	"fripon_lame",
	"fripon_frenesie"
]


# =======================================================
# CONSTANTES — Gameplay
# =======================================================

const COUT_PM_FORET    : int = 2   # PM consommés pour entrer en forêt
const RAYON_BOMBE      : int = 1   # Distance Manhattan de la zone d'explosion
const DEGATS_BOMBE     : int = 20  # Dégâts infligés par la bombe dans sa zone
const SOIN_POTION      : int = 30  # HP restaurés par la Potion de Soin
const DUREE_CAPE_FORET : int = 2   # Tours de durée de la forêt créée par la Cape

# Flèches Empoisonnées — DoT appliqué sur la cible après attaque de base
const DOT_FLECHES_DEGATS : int = 5
const DOT_FLECHES_DUREE  : int = 3


# =======================================================
# RÉFÉRENCES — Injectées par main.gd dans _ready()
# =======================================================

var board           : Node = null  # board.gd
var renderer        : Node = null  # renderer.gd
var tour_manager    : Node = null  # tour_manager.gd
var hud_ui          : Node = null  # hud_ui.gd
var event_manager   : Node = null  # event_manager.gd
var inventory_ui    : Node = null  # inventory_ui.gd
var sort_handler    : Node = null  # sort_handler.gd
var effects_handler : Node = null  # effects_handler.gd
var sort_ui         : Node = null  # sort_ui.gd


# =======================================================
# ÉTAT — Listes partagées avec main.gd
# =======================================================

var joueurs       : Array[Node]       = []  # [joueur1, joueur2, joueur3]
var pieges_actifs : Array[Dictionary] = []  # Pièges actifs sur le plateau


# =======================================================
# ÉTAT — Interne
# =======================================================

var joueur_selectionne : bool = false  # Un joueur est-il sélectionné ?
var sort_selectionne   : int  = -1     # Index du sort sélectionné (-1 = aucun)
var boutique_ouverte   : bool = false  # La boutique bloque-t-elle les inputs ?

# Modes de ciblage spéciaux — actifs quand un item attend un clic de positionnement
var bombe_en_attente : Item = null  # Bombe en attente d'une case cible
var cape_en_attente  : Item = null  # Cape de Forêt en attente d'une case cible


# =======================================================
# CALLBACKS — Définis par main.gd pour déléguer les actions post-input
# =======================================================

var on_rafraichir_hud : Callable  # func()
var on_log            : Callable  # func(message, joueur)


# =======================================================
# POINT D'ENTRÉE — Traitement des inputs
# =======================================================
func _input(event: InputEvent) -> void:

	# Bloque tous les inputs de jeu quand l'inventaire est ouvert
	if inventory_ui._visible:
		if event is InputEventKey and event.pressed:
			if event.keycode == TOUCHE_INVENTAIRE:
				inventory_ui.toggle(tour_manager.get_joueur_actif())
		return

	# Touche F — inventaire, autorisé même boutique ouverte
	if event is InputEventKey and event.pressed:
		if event.keycode == TOUCHE_INVENTAIRE:
			inventory_ui.toggle(tour_manager.get_joueur_actif())
			return

	# Boutique ouverte — bloque tous les autres inputs
	if boutique_ouverte:
		return

	if event is InputEventKey and event.pressed:
		_traiter_input_clavier(event)
		return

	if event is InputEventMouseButton and event.pressed:
		_traiter_clic_souris(event)


# =======================================================
# TRAITEMENT CLAVIER
# =======================================================
func _traiter_input_clavier(event: InputEventKey) -> void:
	var joueur_actif : Node = tour_manager.get_joueur_actif()

	# Les sorts ne sont accessibles que si le joueur est sélectionné
	if not joueur_selectionne:
		return

	var index_sort : int = _get_index_sort_depuis_touche(event)
	if index_sort < 0 or index_sort >= joueur_actif.sorts.size():
		return

	# Vérifie que le sort est bien débloqué ce tour
	# sorts_debloques = 1 au tour 1, puis +1 tous les 2 tours globaux
	if index_sort >= joueur_actif.sorts_debloques:
		on_log.call("🔒 Sort %d verrouillé — disponible au tour %d" % [
			index_sort + 1,
			1 + (index_sort * 2)
		], joueur_actif)
		return

	var sort : Sort = joueur_actif.sorts[index_sort]

	# Cas spécial — Dérobade avec une marque déjà posée :
	# on explose immédiatement sans vérifier CD/PM
	if sort.id == ID_SORT_DEROBADE and joueur_actif.get("marque_cible") != null:
		sort_handler.exploser_marque_derobade(joueur_actif)
		_reset_selection()
		renderer.joueur_selectionne = false
		renderer.sort_selectionne   = -1
		renderer.rafraichir()
		if sort_ui != null:
			sort_ui.rafraichir()
		on_rafraichir_hud.call()
		return

	# Vérifications avant sélection du sort
	if not sort.est_disponible():
		on_log.call("⏳ %s en recharge — %d tour(s) restant(s)" % [sort.nom, sort.cooldown_actuel], joueur_actif)
		return
	if joueur_actif.gold < sort.cout_gold:
		on_log.call("💰 Gold insuffisant — %s coûte %d Gold (tu as %d)" % [sort.nom, sort.cout_gold, joueur_actif.gold], joueur_actif)
		return
	if joueur_actif.pm_actuels < sort.cout_pm:
		on_log.call("🔵 PM insuffisants — %s coûte %d PM (il te reste %d)" % [sort.nom, sort.cout_pm, joueur_actif.pm_actuels], joueur_actif)
		return

	# Sorts auto-ciblants → activation immédiate sur le lanceur,
	# sans afficher de surbrillance ni attendre un clic
	if sort.id in SORTS_AUTO_CIBLANTS:
		var reussi : bool = sort_handler.utiliser_sort(
			joueur_actif, sort,
			joueur_actif.grid_x, joueur_actif.grid_y
		)
		if reussi:
			_reset_selection()
			renderer.joueur_selectionne = false
			renderer.sort_selectionne   = -1
			renderer.rafraichir()
			if sort_ui != null:
				sort_ui.rafraichir()
			on_rafraichir_hud.call()
		return

	# Sélection / désélection du sort
	if sort_selectionne == index_sort:
		sort_selectionne = -1
	else:
		sort_selectionne = index_sort

	renderer.sort_selectionne = sort_selectionne
	renderer.rafraichir()
	if sort_ui != null:
		sort_ui.rafraichir()


# =======================================================
# TRAITEMENT CLIC SOURIS
# =======================================================
func _traiter_clic_souris(event: InputEventMouseButton) -> void:
	var cell         : Vector2i = renderer.screen_to_grid(event.position)
	var joueur_actif : Node     = tour_manager.get_joueur_actif()

	if _est_hors_plateau(cell):
		if joueur_selectionne or sort_selectionne >= 0:
			_reset_selection()
			renderer.joueur_selectionne = false
			renderer.sort_selectionne   = -1
			renderer.rafraichir()
			if sort_ui != null:
				sort_ui.rafraichir()
		return

	if bombe_en_attente != null:
		_appliquer_bombe(cell, joueur_actif)
		return

	if cape_en_attente != null:
		_appliquer_cape_foret(cell, joueur_actif)
		return

	if not joueur_actif.est_place:
		_placer_joueur(joueur_actif, cell)
		return

	# PRIORITÉ : un sort est sélectionné (via card ou clavier)
	# → on tente de l'utiliser AVANT toute autre logique
	if sort_selectionne >= 0:
		_utiliser_sort_sur_clic(joueur_actif, cell)
		return

	# Reclique sur soi-même → désélection
	var est_sur_soi : bool = cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y
	if joueur_selectionne and est_sur_soi:
		_reset_selection()
		renderer.joueur_selectionne = false
		renderer.rafraichir()
		return

	if not joueur_selectionne:
		_selectionner_joueur(joueur_actif, cell)
		return

	_traiter_deplacement_ou_attaque(joueur_actif, cell)


# =======================================================
# PLACEMENT INITIAL
# =======================================================
func _placer_joueur(joueur_actif: Node, cell: Vector2i) -> void:
	if board.case_occupee(cell.x, cell.y):
		return

	var type_case : int = board.get_case(cell.x, cell.y)
	if type_case in [board.CaseType.VIDE, board.CaseType.MUR]:
		return

	board.occuper_case(cell.x, cell.y)
	joueur_actif.placer(cell.x, cell.y)
	on_rafraichir_hud.call()
	renderer.rafraichir()


# =======================================================
# SÉLECTION DU JOUEUR
# =======================================================
func _selectionner_joueur(joueur_actif: Node, cell: Vector2i) -> void:
	var est_sur_le_joueur : bool = cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y
	if not est_sur_le_joueur:
		return
	var peut_agir : bool = joueur_actif.peut_se_deplacer() or not joueur_actif.a_attaque_ce_tour
	if peut_agir:
		joueur_selectionne          = true
		renderer.joueur_selectionne = true
		renderer.rafraichir()


# =======================================================
# UTILISATION D'UN SORT AU CLIC
# =======================================================
func _utiliser_sort_sur_clic(joueur_actif: Node, cell: Vector2i) -> void:
	# Les sorts auto-ciblants ne passent jamais par un clic de case
	# Ils sont gérés directement dans _traiter_input_clavier() et _on_sort_clique()
	var sort_actif : Sort = joueur_actif.sorts[sort_selectionne]
	if sort_actif.id in SORTS_AUTO_CIBLANTS:
		_reset_selection()
		renderer.rafraichir()
		return

	var sort : Sort = joueur_actif.sorts[sort_selectionne]

	# La Flèche Rebondissante utilise attaque_portee pour bénéficier
	# du passif Forêt de l'Archer (+1 portée via entrer_foret())
	var portee_effective : int
	if sort.id == "archer_fleche":
		portee_effective = joueur_actif.attaque_portee
	else:
		portee_effective = sort.portee + joueur_actif.bonus_range_sorts

	var distance : int  = abs(cell.x - joueur_actif.grid_x) + abs(cell.y - joueur_actif.grid_y)
	var a_portee : bool = (sort.portee == 0) or (distance <= portee_effective)

	if not a_portee:
		return

	var sort_reussi : bool = sort_handler.utiliser_sort(joueur_actif, sort, cell.x, cell.y)
	if sort_reussi:
		_reset_selection()
		renderer.joueur_selectionne = false
		renderer.sort_selectionne   = -1
		renderer.rafraichir()
		if sort_ui != null:
			sort_ui.rafraichir()
		on_rafraichir_hud.call()


# =======================================================
# DÉPLACEMENT OU ATTAQUE DE BASE
# =======================================================
func _traiter_deplacement_ou_attaque(joueur_actif: Node, cell: Vector2i) -> void:
	var joueur_cible : Node       = _get_joueur_en(cell.x, cell.y)
	var mine         : Dictionary = event_manager.get_mine_en(cell.x, cell.y)

	if joueur_cible != null and joueur_cible != joueur_actif:
		_attaquer(joueur_actif, joueur_cible)
	elif mine != {}:
		# Attaque de base sur une mine — même vérifications que sur un joueur
		if not joueur_actif.peut_attaquer(cell.x, cell.y):
			return
		joueur_actif.pm_actuels       -= joueur_actif.attaque_cout_pm
		joueur_actif.a_attaque_ce_tour = true
		event_manager.attaquer_mine(cell.x, cell.y, joueur_actif.attaque_degats, joueur_actif)
		joueur_actif.gagner_gold_sur_degats(joueur_actif.attaque_degats)
		joueur_selectionne = false
		on_rafraichir_hud.call()
	elif joueur_actif.peut_se_deplacer_vers(cell.x, cell.y):
		_deplacer(joueur_actif, cell)

	renderer.joueur_actif       = joueur_actif
	renderer.joueur_selectionne = joueur_selectionne
	renderer.rafraichir()


# -------------------------------------------------------
# Attaque de base — avec synergies Flèches et Pickpocket
# -------------------------------------------------------
func _attaquer(attaquant: Node, cible: Node) -> void:
	if attaquant.a_attaque_ce_tour:
		on_log.call("⚔️ Tu as déjà attaqué ce tour !", attaquant)
		return
	if attaquant.pm_actuels < attaquant.attaque_cout_pm:
		on_log.call("🔵 PM insuffisants pour attaquer (%d requis)" % attaquant.attaque_cout_pm, attaquant)
		return
	if not attaquant.peut_attaquer(cible.grid_x, cible.grid_y):
		on_log.call("⚔️ Cible hors de portée !", attaquant)
		return

	attaquant.attaquer(cible)
	on_log.call("⚔️ %s attaque %s — %d dmg" % [
		attaquant.name, cible.name, attaquant.attaque_degats
	], attaquant)

	if cible.est_mort:
		on_log.call("💀 %s éliminé !" % cible.name, attaquant)

	# Synergie Flèches Empoisonnées
	if attaquant.fleches_empoisonnees_actif:
		cible.ajouter_dot("fleches_empoisonnees", DOT_FLECHES_DEGATS, DOT_FLECHES_DUREE)
		attaquant.fleches_empoisonnees_actif = false
		_retirer_item(attaquant, "fleches_empoisonnees")
		on_log.call("🏹 Flèches Empoisonnées — DoT %d/tour (%dT) sur %s" % [DOT_FLECHES_DEGATS, DOT_FLECHES_DUREE, cible.name], attaquant)

	# Synergie Pickpocket
	if attaquant.pickpocket_actif and cible.gold > 0:
		cible.gold     -= 1
		attaquant.gold += 1
		on_log.call("💰 Pickpocket — 1 Gold volé à %s" % cible.name, attaquant)

	joueur_selectionne = false
	on_rafraichir_hud.call()


# -------------------------------------------------------
# Déplacement — avec passif Fripon et effets de case
# -------------------------------------------------------
func _deplacer(joueur_actif: Node, cell: Vector2i) -> void:
	var type_case_arrivee : int = board.get_case(cell.x, cell.y)

	if type_case_arrivee in [board.CaseType.VIDE, board.CaseType.MUR]:
		return

	if board.case_occupee(cell.x, cell.y):
		return

	# Validation BFS — vérifie que le chemin est réellement accessible
	# (remplace le calcul Manhattan qui ignorait les obstacles)
	var cases_accessibles : Dictionary = renderer._calculer_cases_accessibles(
		joueur_actif.grid_x,
		joueur_actif.grid_y,
		joueur_actif.pm_actuels
	)
	var cle_cible : String = "%d,%d" % [cell.x, cell.y]
	if not cases_accessibles.has(cle_cible):
		return

	# Le coût PM réel est celui calculé par le BFS (tient compte de la Forêt et du chemin)
	var cout_pm : int = cases_accessibles[cle_cible]

	board.liberer_case(joueur_actif.grid_x, joueur_actif.grid_y)
	joueur_actif.deplacer(cell.x, cell.y, cout_pm)

	# Passif Fripon — réinitialise a_attaque_ce_tour après chaque déplacement
	# pour permettre une seconde attaque
	if joueur_actif.get_classe() == "fripon":
		joueur_actif.a_attaque_ce_tour = false

	# Suivi du déplacement pour les passifs qui en dépendent
	if joueur_actif.get("s_est_deplace_ce_tour") != null:
		joueur_actif.s_est_deplace_ce_tour = true

	effects_handler.appliquer_effet_case(joueur_actif)
	effects_handler.verifier_pieges(joueur_actif, pieges_actifs)
	event_manager.verifier_ramassage(joueur_actif)

	board.occuper_case(joueur_actif.grid_x, joueur_actif.grid_y)
	joueur_selectionne = false
	on_rafraichir_hud.call()


# =======================================================
# MODES DE CIBLAGE SPÉCIAUX — Items
# =======================================================

# -------------------------------------------------------
# Bombe — zone d'explosion Manhattan ≤ RAYON_BOMBE
# Appelée par inventory_ui via le signal bombe_demande_cible
# -------------------------------------------------------
func activer_mode_bombe(item: Item) -> void:
	bombe_en_attente = item


func _appliquer_bombe(cell: Vector2i, joueur_actif: Node) -> void:
	for j in joueurs:
		if not j.est_place or j.est_mort:
			continue
		var distance : int = abs(j.grid_x - cell.x) + abs(j.grid_y - cell.y)
		if distance <= RAYON_BOMBE:
			j.recevoir_degats(DEGATS_BOMBE)

	_retirer_item(joueur_actif, bombe_en_attente.id)
	bombe_en_attente = null
	on_rafraichir_hud.call()
	renderer.rafraichir()


# -------------------------------------------------------
# Potion de Soin — restaure SOIN_POTION HP sur le joueur actif.
# Appelée par inventory_ui via le signal potion_utilisee.
# -------------------------------------------------------
func appliquer_potion(item: Item) -> void:
	var joueur_actif : Node = tour_manager.get_joueur_actif()
	joueur_actif.hp_actuels = min(joueur_actif.hp_actuels + SOIN_POTION, joueur_actif.hp_max)
	_retirer_item(joueur_actif, item.id)
	on_rafraichir_hud.call()


# -------------------------------------------------------
# Cape de Forêt — crée une case Forêt temporaire (DUREE_CAPE_FORET tours)
# Appelée par inventory_ui via le signal cape_utilisee
# -------------------------------------------------------
func activer_mode_cape_foret(item: Item) -> void:
	cape_en_attente = item


func _appliquer_cape_foret(cell: Vector2i, joueur_actif: Node) -> void:
	var type_case : int = board.get_case(cell.x, cell.y)

	if type_case in [board.CaseType.VIDE, board.CaseType.MUR, board.CaseType.TOUR]:
		return

	var case_transformee : Array[Dictionary] = [{ "x": cell.x, "y": cell.y, "type_original": type_case }]
	board.plateau[cell.x][cell.y] = board.CaseType.FORET

	sort_handler.forets_temporaires.append({
		"cases"          : case_transformee,
		"tours_restants" : DUREE_CAPE_FORET,
		"lanceur"        : joueur_actif
	})

	joueur_actif.cape_foret_charges -= 1

	# Retire l'item quand toutes les charges sont épuisées
	if joueur_actif.cape_foret_charges <= 0:
		_retirer_item(joueur_actif, cape_en_attente.id)

	cape_en_attente = null
	on_rafraichir_hud.call()
	renderer.rafraichir()


# -------------------------------------------------------
# Bandage — réduit la durée de tous les DoT actifs de 1 tour.
# Appelée par inventory_ui via le signal bandage_utilise.
# L'item est consommé immédiatement (usage unique).
# -------------------------------------------------------
func appliquer_bandage(item: Item) -> void:
	var joueur_actif : Node          = tour_manager.get_joueur_actif()
	var dots_expires : Array[String] = []
	for source_id in joueur_actif.dots_actifs:
		joueur_actif.dots_actifs[source_id]["tours_restants"] -= 1
		if joueur_actif.dots_actifs[source_id]["tours_restants"] <= 0:
			dots_expires.append(source_id)
	for source_id in dots_expires:
		joueur_actif.dots_actifs.erase(source_id)
	_retirer_item(joueur_actif, item.id)
	on_rafraichir_hud.call()


# -------------------------------------------------------
# Flèches Empoisonnées — active le flag pour la prochaine attaque.
# Appelée par inventory_ui via le signal fleches_utilisees.
#
# Le flag fleches_empoisonnees_actif est consommé dans _attaquer()
# dès que l'Archer touche une cible (une seule attaque).
# -------------------------------------------------------
func appliquer_fleches_empoisonnees(_item: Item) -> void:
	var joueur_actif : Node = tour_manager.get_joueur_actif()
	joueur_actif.fleches_empoisonnees_actif = true
	on_rafraichir_hud.call()


# =======================================================
# HELPERS PRIVÉS
# =======================================================

# -------------------------------------------------------
# Retire le premier item correspondant à l'id donné.
# erase() compare les références — pas fiable si l'instance
# passée en signal est différente de celle dans l'inventaire.
# -------------------------------------------------------
func _retirer_item(joueur: Node, item_id: String) -> void:
	for i in range(joueur.inventaire.size()):
		if joueur.inventaire[i].id == item_id:
			joueur.inventaire.remove_at(i)
			return


# -------------------------------------------------------
# Retourne l'index du sort selon la touche pressée (A/Z/E/R).
# Retourne -1 si aucune touche de sort n'est pressée.
# -------------------------------------------------------
func _get_index_sort_depuis_touche(event: InputEventKey) -> int:
	if event.is_action("sort_1"): return 0
	if event.is_action("sort_2"): return 1
	if event.is_action("sort_3"): return 2
	if event.is_action("sort_4"): return 3
	return -1


# -------------------------------------------------------
# Réinitialise la sélection joueur et sort.
# -------------------------------------------------------
func _reset_selection() -> void:
	joueur_selectionne          = false
	sort_selectionne            = -1
	renderer.joueur_selectionne = joueur_selectionne
	renderer.sort_selectionne   = sort_selectionne


# -------------------------------------------------------
# Vérifie si une case est en dehors du plateau.
# -------------------------------------------------------
func _est_hors_plateau(cell: Vector2i) -> bool:
	return cell.x < 0 or cell.x >= board.TAILLE_PLATEAU or cell.y < 0 or cell.y >= board.TAILLE_PLATEAU


# -------------------------------------------------------
# Retourne le joueur vivant présent sur la case (x, y).
# Retourne null si la case est vide ou si le joueur est mort.
# -------------------------------------------------------
func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in joueurs:
		var est_actif : bool = joueur.est_place and not joueur.est_mort
		if est_actif and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null
