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
#
# NE contient PAS de logique de gameplay.
# Délègue tout à sort_handler et effects_handler.
# =======================================================
extends Node

# -------------------------------------------------------
# Constantes — touches clavier
# -------------------------------------------------------
const TOUCHE_INVENTAIRE : int = KEY_F  # Ouvre/ferme l'inventaire

# -------------------------------------------------------
# Constantes — identifiants de sort pour le cas spécial Dérobade
# -------------------------------------------------------
const ID_SORT_DEROBADE : String = "fripon_derobade"

# -------------------------------------------------------
# Constantes — détection de classe Fripon
# Utilisé pour le passif de déplacement
# -------------------------------------------------------
const CHEMIN_SCRIPT_FRIPON : String = "fripon"

# -------------------------------------------------------
# Constantes — gameplay
# -------------------------------------------------------
const COUT_PM_FORET    : int = 2  # PM consommés pour entrer en forêt
const RAYON_BOMBE      : int = 1  # Distance Manhattan de la zone d'explosion de la bombe
const DEGATS_BOMBE     : int = 20 # Dégâts infligés par la bombe dans sa zone

# -------------------------------------------------------
# Références injectées par main.gd dans _ready()
# -------------------------------------------------------
var board           : Node = null  # board.gd
var renderer        : Node = null  # renderer.gd
var tour_manager    : Node = null  # tour_manager.gd
var log_ui          : Node = null  # log_ui.gd
var hud_ui          : Node = null  # hud_ui.gd
var event_manager   : Node = null  # event_manager.gd
var inventory_ui    : Node = null  # inventory_ui.gd
var sort_handler    : Node = null  # sort_handler.gd
var effects_handler : Node = null  # effects_handler.gd

# -------------------------------------------------------
# Listes partagées — injectées par main.gd
# -------------------------------------------------------
var joueurs      : Array = []  # [joueur1, joueur2, joueur3]
var pieges_actifs: Array = []  # Pièges actifs sur le plateau

# -------------------------------------------------------
# État interne de l'input handler
# -------------------------------------------------------
var joueur_selectionne : bool = false  # Un joueur est-il sélectionné ?
var sort_selectionne   : int  = -1     # Index du sort sélectionné (-1 = aucun)
var boutique_ouverte   : bool = false  # La boutique bloque-t-elle les inputs ?

# -------------------------------------------------------
# Modes de ciblage spéciaux
# Actifs quand l'item correspondant attend un clic
# -------------------------------------------------------
var bombe_en_attente   : Resource = null  # Item Bombe en attente d'une case cible
var cape_en_attente    : Resource = null  # Item Cape de Forêt en attente d'une case cible

# -------------------------------------------------------
# Callbacks — définis par main.gd pour déléguer
# les actions post-input (log, hud, fin de tour, etc.)
# -------------------------------------------------------
var on_log           : Callable  # Signature : func(message, joueur)
var on_rafraichir_hud: Callable  # Signature : func()


# =======================================================
# POINT D'ENTRÉE — Traitement des inputs
# =======================================================
func _input(event: InputEvent) -> void:

	# -------------------------------------------------------
	# TOUCHE F — Inventaire
	# Autorisé même pendant la boutique
	# -------------------------------------------------------
	if event is InputEventKey and event.pressed:
		if event.keycode == TOUCHE_INVENTAIRE:
			inventory_ui.toggle(tour_manager.get_joueur_actif())
			return

	# -------------------------------------------------------
	# BOUTIQUE OUVERTE — bloque tous les autres inputs
	# -------------------------------------------------------
	if boutique_ouverte:
		return

	# -------------------------------------------------------
	# TRAITEMENT CLAVIER
	# -------------------------------------------------------
	if event is InputEventKey and event.pressed:
		_traiter_input_clavier(event)
		return

	# -------------------------------------------------------
	# TRAITEMENT SOURIS
	# -------------------------------------------------------
	if event is InputEventMouseButton and event.pressed:
		_traiter_clic_souris(event)


# =======================================================
# TRAITEMENT CLAVIER
# =======================================================
func _traiter_input_clavier(event: InputEventKey) -> void:
	var joueur_actif : Node = tour_manager.get_joueur_actif()

	# Un joueur doit être sélectionné pour utiliser les sorts
	if not joueur_selectionne:
		return

	# Détermine l'index du sort appuyé (A/Z/E/R)
	var index_sort : int = _get_index_sort_depuis_touche(event)
	if index_sort < 0 or index_sort >= joueur_actif.sorts.size():
		return

	var sort : Resource = joueur_actif.sorts[index_sort]

	# -------------------------------------------------------
	# CAS SPÉCIAL — Dérobade avec marque déjà active
	# Explosion IMMÉDIATE sans vérification CD/PM
	# -------------------------------------------------------
	if sort.id == ID_SORT_DEROBADE and joueur_actif.get("marque_cible") != null:
		sort_handler.exploser_marque_derobade(joueur_actif)
		_reset_selection()
		renderer.queue_redraw()
		on_rafraichir_hud.call()
		return

	# -------------------------------------------------------
	# Vérifications avant sélection du sort
	# -------------------------------------------------------
	if not sort.est_disponible():
		print("Sort en recharge ! (%d tours restants)" % sort.cooldown_actuel)
		return
	if joueur_actif.gold < sort.cout_gold:
		print("Pas assez de Gold pour ce sort !")
		return
	if joueur_actif.pm_actuels < sort.cout_pm:
		print("Pas assez de PM ! (%d requis, %d restants)" % [sort.cout_pm, joueur_actif.pm_actuels])
		return

	# -------------------------------------------------------
	# Sélection / désélection du sort
	# -------------------------------------------------------
	if sort_selectionne == index_sort:
		sort_selectionne = -1
		print("Sort désélectionné")
	else:
		sort_selectionne = index_sort
		print("Sort sélectionné : %s — Portée : %d" % [sort.nom, sort.portee])

	renderer.sort_selectionne = sort_selectionne
	renderer.queue_redraw()


# =======================================================
# TRAITEMENT CLIC SOURIS
# =======================================================
func _traiter_clic_souris(event: InputEventMouseButton) -> void:
	var cell         : Vector2i = renderer.screen_to_grid(event.position)
	var joueur_actif : Node     = tour_manager.get_joueur_actif()

	# Clic hors plateau → désélection
	if _est_hors_plateau(cell):
		if joueur_selectionne:
			_reset_selection()
			renderer.queue_redraw()
		return

	# -------------------------------------------------------
	# MODE CIBLAGE BOMBE
	# Priorité sur tout autre clic
	# -------------------------------------------------------
	if bombe_en_attente != null:
		_appliquer_bombe(cell, joueur_actif)
		return

	# -------------------------------------------------------
	# MODE CIBLAGE CAPE DE FORÊT
	# -------------------------------------------------------
	if cape_en_attente != null:
		_appliquer_cape_foret(cell, joueur_actif)
		return

	# -------------------------------------------------------
	# PLACEMENT INITIAL — joueur non encore placé
	# -------------------------------------------------------
	if not joueur_actif.est_place:
		_placer_joueur(joueur_actif, cell)
		return

	# -------------------------------------------------------
	# SÉLECTION DU JOUEUR
	# -------------------------------------------------------
	if not joueur_selectionne:
		_selectionner_joueur(joueur_actif, cell)
		return

	# -------------------------------------------------------
	# SORT SÉLECTIONNÉ — clic = utilisation du sort
	# -------------------------------------------------------
	if sort_selectionne >= 0:
		_utiliser_sort_sur_clic(joueur_actif, cell)
		return

	# -------------------------------------------------------
	# PAS DE SORT — clic = déplacement ou attaque de base
	# -------------------------------------------------------
	_traiter_deplacement_ou_attaque(joueur_actif, cell)


# =======================================================
# PLACEMENT INITIAL
# =======================================================
func _placer_joueur(joueur_actif: Node, cell: Vector2i) -> void:
	if board.case_occupee(cell.x, cell.y):
		print("Case déjà occupée !")
		return
	board.occuper_case(cell.x, cell.y)
	joueur_actif.placer(cell.x, cell.y)
	on_log.call("📍 %s placé en (%d,%d)" % [joueur_actif.name, cell.x, cell.y], joueur_actif)
	on_rafraichir_hud.call()
	renderer.queue_redraw() 


# =======================================================
# SÉLECTION DU JOUEUR
# =======================================================
func _selectionner_joueur(joueur_actif: Node, cell: Vector2i) -> void:
	var est_sur_le_joueur : bool = cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y
	if not est_sur_le_joueur:
		return
	var peut_agir : bool = joueur_actif.peut_se_deplacer() or not joueur_actif.a_attaque_ce_tour
	if peut_agir:
		joueur_selectionne = true
		renderer.joueur_selectionne = true
		print("Joueur sélectionné — PM : %d" % joueur_actif.pm_actuels)
		renderer.queue_redraw()
	else:
		print("Plus de PM et déjà attaqué !")


# =======================================================
# UTILISATION D'UN SORT AU CLIC
# =======================================================
func _utiliser_sort_sur_clic(joueur_actif: Node, cell: Vector2i) -> void:
	var sort : Resource = joueur_actif.sorts[sort_selectionne]

	# Calcule la portée effective
	# Cas spécial : Flèche Rebondissante utilise attaque_portee
	var portee_effective : int
	if sort.id == "archer_fleche":
		portee_effective = joueur_actif.attaque_portee
	else:
		portee_effective = sort.portee + joueur_actif.bonus_range_sorts

	var distance  : int  = abs(cell.x - joueur_actif.grid_x) + abs(cell.y - joueur_actif.grid_y)
	var a_portee  : bool = (sort.portee == 0) or (distance <= portee_effective)

	if not a_portee:
		print("Cible hors de portée du sort !")
		return

	var sort_reussi : bool = sort_handler.utiliser_sort(joueur_actif, sort, cell.x, cell.y)
	if sort_reussi:
		_reset_selection()
		on_rafraichir_hud.call()


# =======================================================
# DÉPLACEMENT OU ATTAQUE DE BASE
# =======================================================
func _traiter_deplacement_ou_attaque(joueur_actif: Node, cell: Vector2i) -> void:
	var joueur_cible : Node = _get_joueur_en(cell.x, cell.y)

	# -------------------------------------------------------
	# ATTAQUE DE BASE — clic sur un ennemi
	# -------------------------------------------------------
	if joueur_cible != null:
		_attaquer(joueur_actif, joueur_cible)

	# -------------------------------------------------------
	# DÉPLACEMENT — clic sur une case accessible
	# -------------------------------------------------------
	elif joueur_actif.peut_se_deplacer_vers(cell.x, cell.y):
		_deplacer(joueur_actif, cell)

	else:
		print("Case inaccessible !")

	renderer.joueur_actif      = joueur_actif
	renderer.joueur_selectionne = joueur_selectionne
	renderer.queue_redraw()


# -------------------------------------------------------
# Attaque de base — avec synergie Flèches et Pickpocket
# -------------------------------------------------------
func _attaquer(attaquant: Node, cible: Node) -> void:
	if not attaquant.peut_attaquer(cible.grid_x, cible.grid_y):
		if attaquant.a_attaque_ce_tour:
			print("Déjà attaqué ce tour !")
		elif attaquant.pm_actuels < attaquant.attaque_cout_pm:
			print("Pas assez de PM !")
		else:
			print("Cible hors de portée !")
		return

	attaquant.attaquer(cible)

	# Synergie Flèches Empoisonnées (Archer)
	if attaquant.fleches_empoisonnees_actif:
		cible.ajouter_dot("fleches_empoisonnees", 5, 3)
		attaquant.fleches_empoisonnees_actif = false
		on_log.call("🏹 Flèches Empoisonnées ! DoT sur %s" % cible.name, attaquant)

	# Synergie Ceinture de Pickpocket (Fripon)
	if attaquant.pickpocket_actif and cible.gold > 0:
		cible.gold    -= 1
		attaquant.gold += 1
		on_log.call("👜 %s vole 1 Gold à %s !" % [attaquant.name, cible.name], attaquant)

	on_log.call("⚔️ %s attaque %s — %d dmg" % [attaquant.name, cible.name, attaquant.attaque_degats], attaquant)
	joueur_selectionne = false
	on_rafraichir_hud.call()


# -------------------------------------------------------
# Déplacement — avec passif Fripon et effets de case
# -------------------------------------------------------
func _deplacer(joueur_actif: Node, cell: Vector2i) -> void:
	var type_case_arrivee : int = board.get_case(cell.x, cell.y)

	# Cases infranchissables
	if type_case_arrivee in [board.CaseType.VIDE, board.CaseType.MUR]:
		print("Case infranchissable !")
		return

	# Case déjà occupée par un autre joueur
	if board.case_occupee(cell.x, cell.y):
		print("Case occupée !")
		return

	# Coût PM : 2 pour la forêt, distance normale sinon
	var cout_pm : int = COUT_PM_FORET if type_case_arrivee == board.CaseType.FORET else -1

	board.liberer_case(joueur_actif.grid_x, joueur_actif.grid_y)
	joueur_actif.deplacer(cell.x, cell.y, cout_pm)

	# Passif Fripon — reset a_attaque_ce_tour après chaque déplacement
	# → le Fripon peut réattaquer après s'être déplacé
	if "fripon" in joueur_actif.get_script().resource_path:
		joueur_actif.a_attaque_ce_tour = false

	# Marque le déplacement (utilisé par l'Archer pour son passif)
	if joueur_actif.get("s_est_deplace_ce_tour") != null:
		joueur_actif.s_est_deplace_ce_tour = true

	# Applique l'effet de la case d'arrivée
	effects_handler.appliquer_effet_case(joueur_actif)
	# Vérifie les pièges ennemis sur la case
	effects_handler.verifier_pieges(joueur_actif, pieges_actifs)
	# Vérifie le ramassage (tas de pièces, coffres)
	event_manager.verifier_ramassage(joueur_actif)

	board.occuper_case(joueur_actif.grid_x, joueur_actif.grid_y)
	joueur_selectionne = false
	on_log.call("🚶 %s → (%d,%d) — PM : %d" % [joueur_actif.name, cell.x, cell.y, joueur_actif.pm_actuels], joueur_actif)
	on_rafraichir_hud.call()


# =======================================================
# MODES DE CIBLAGE SPÉCIAUX — Items
# =======================================================

# -------------------------------------------------------
# Bombe — zone d'explosion en croix (Manhattan ≤ 1)
# Activée par inventory_ui quand le joueur clique "Lancer"
# -------------------------------------------------------
func activer_mode_bombe(item: Resource) -> void:
	bombe_en_attente = item
	print("💣 Mode ciblage Bombe activé — cliquez sur une case")


func _appliquer_bombe(cell: Vector2i, joueur_actif: Node) -> void:
	# Zone d'explosion : case centrale + cases adjacentes (distance Manhattan ≤ 1)
	for j in joueurs:
		if not j.est_place or j.est_mort:
			continue
		var distance : int = abs(j.grid_x - cell.x) + abs(j.grid_y - cell.y)
		if distance <= RAYON_BOMBE:
			j.recevoir_degats(DEGATS_BOMBE)
			on_log.call("💣 Explosion ! %d dmg sur %s" % [DEGATS_BOMBE, j.name], joueur_actif)

	# Retire l'item de l'inventaire après utilisation
	joueur_actif.inventaire.erase(bombe_en_attente)
	bombe_en_attente = null
	on_rafraichir_hud.call()
	renderer.queue_redraw()


# -------------------------------------------------------
# Cape de Forêt — crée une case Forêt temporaire
# Activée par inventory_ui quand le joueur clique "Utiliser"
# -------------------------------------------------------
func activer_mode_cape_foret(item: Resource) -> void:
	cape_en_attente = item
	print("🌲 Mode ciblage Cape de Forêt activé — cliquez sur une case")


func _appliquer_cape_foret(cell: Vector2i, joueur_actif: Node) -> void:
	var type_case : int = board.get_case(cell.x, cell.y)

	# Empêche de placer une forêt sur une case invalide
	if type_case in [board.CaseType.VIDE, board.CaseType.MUR, board.CaseType.TOUR]:
		print("Impossible de placer la Cape ici !")
		return

	# Crée la forêt temporaire (1 case, 2 tours de l'Archer)
	var case_transformee : Array = [{ "x": cell.x, "y": cell.y, "type_original": type_case }]
	board.plateau[cell.x][cell.y] = board.CaseType.FORET

	sort_handler.forets_temporaires.append({
		"cases"          : case_transformee,
		"tours_restants" : 2,
		"lanceur"        : joueur_actif
	})

	# Décrémente les charges restantes
	joueur_actif.cape_foret_charges -= 1

	# Retire l'item si plus de charges
	if joueur_actif.cape_foret_charges <= 0:
		joueur_actif.inventaire.erase(cape_en_attente)

	cape_en_attente = null
	on_log.call("🌲 %s crée une Forêt en (%d,%d)" % [joueur_actif.name, cell.x, cell.y], joueur_actif)
	on_rafraichir_hud.call()
	renderer.queue_redraw()


# =======================================================
# HELPERS
# =======================================================

# -------------------------------------------------------
# Retourne l'index du sort selon la touche pressée
# Retourne -1 si aucune touche de sort n'est pressée
# -------------------------------------------------------
func _get_index_sort_depuis_touche(event: InputEventKey) -> int:
	if event.is_action("sort_1"): return 0
	if event.is_action("sort_2"): return 1
	if event.is_action("sort_3"): return 2
	if event.is_action("sort_4"): return 3
	return -1


# -------------------------------------------------------
# Réinitialise la sélection joueur et sort
# -------------------------------------------------------
func _reset_selection() -> void:
	joueur_selectionne          = false
	sort_selectionne            = -1
	renderer.joueur_selectionne = false
	renderer.sort_selectionne   = -1


# -------------------------------------------------------
# Vérifie si une case est en dehors du plateau 8x8
# -------------------------------------------------------
func _est_hors_plateau(cell: Vector2i) -> bool:
	return cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 8


# -------------------------------------------------------
# Retourne le joueur vivant présent sur la case (x, y)
# -------------------------------------------------------
func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in joueurs:
		var est_actif : bool = joueur.est_place and not joueur.est_mort
		if est_actif and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null
