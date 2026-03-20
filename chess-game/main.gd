# =======================================================
# main.gd
# -------------------------------------------------------
# Rôle UNIQUE : coordination et injection de dépendances.
#
#   - Initialise tous les systèmes dans _ready()
#   - Injecte les références dans les handlers
#   - Connecte tous les signaux
#   - Coordonne fin_de_tour() et les callbacks
#
# Ne contient PAS de logique de gameplay directe.
# Toute la logique est dans les Handlers/.
# =======================================================
extends Node2D

# -------------------------------------------------------
# Références aux nœuds de la scène
# -------------------------------------------------------
@onready var board           : Node      = $Board
@onready var renderer        : Node      = $Renderer
@onready var joueur1         : Node      = $Joueur1
@onready var joueur2         : Node      = $Joueur2
@onready var joueur3         : Node      = $Joueur3
@onready var tour_manager    : Node      = $TourManager
@onready var shop_manager    : Node      = $ShopManager
@onready var shop_ui         : Node      = $ShopUI
@onready var event_manager   : Node      = $EventManager
@onready var hud_ui          : Node      = $HudUI
@onready var inventory_ui    : Node      = $InventoryUI
@onready var game_over_ui    : Node      = $GameOverUi
@onready var camera          : Camera3D  = $Camera3D
@onready var sort_ui         : Node      = $SortUI

# -------------------------------------------------------
# Références aux handlers
# -------------------------------------------------------
@onready var effects_handler : Node = $Handlers/EffectsHandler
@onready var sort_handler    : Node = $Handlers/SortHandler
@onready var input_handler   : Node = $Handlers/InputHandler

# -------------------------------------------------------
# Liste centralisée des joueurs — construite dans _ready()
# -------------------------------------------------------
var _joueurs : Array = []

var _index_joueur_boutique : int = 0

# -------------------------------------------------------
# Listes d'état partagées entre handlers et main
# -------------------------------------------------------
var meteores_en_attente : Array = []
var laves_temporaires   : Array = []
var pieges_actifs       : Array = []
var forets_temporaires  : Array = []
var murs_temporaires    : Array = []


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	add_to_group("main")
	_joueurs = [joueur1, joueur2, joueur3]

	_initialiser_systemes()
	_injecter_references_handlers()
	_connecter_signaux()

	hud_ui.rafraichir(_joueurs, tour_manager.get_joueur_actif())
	renderer.queue_redraw()
	if sort_ui != null:
		sort_ui.rafraichir()

	$Camera3D.position = Vector3(10.0, 10.0, 10.0)
	$Camera3D.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)

	print("✅ Main prêt !")


func _initialiser_systemes() -> void:
	renderer.board         = board
	renderer.joueurs       = _joueurs
	renderer.event_manager = event_manager

	hud_ui.tour_manager = tour_manager
	event_manager.board = board

	tour_manager.initialiser(_joueurs)
	renderer.joueur_actif = tour_manager.get_joueur_actif()

	shop_ui.shop_manager = shop_manager


func _injecter_references_handlers() -> void:

	renderer.camera = camera

	# --- Effects Handler ---
	effects_handler.board    = board
	effects_handler.renderer = renderer
	effects_handler.joueurs  = _joueurs

	# --- Sort Handler ---
	sort_handler.board           = board
	sort_handler.renderer        = renderer
	sort_handler.event_manager   = event_manager
	sort_handler.effects_handler = effects_handler
	sort_handler.joueurs         = _joueurs
	sort_handler.meteores_en_attente = meteores_en_attente
	sort_handler.laves_temporaires   = laves_temporaires
	sort_handler.forets_temporaires  = forets_temporaires
	sort_handler.pieges_actifs       = pieges_actifs
	sort_handler.murs_temporaires    = murs_temporaires

	# --- Input Handler ---
	input_handler.board           = board
	input_handler.renderer        = renderer
	input_handler.tour_manager    = tour_manager
	input_handler.hud_ui          = hud_ui
	input_handler.event_manager   = event_manager
	input_handler.inventory_ui    = inventory_ui
	input_handler.sort_handler    = sort_handler
	input_handler.effects_handler = effects_handler
	input_handler.joueurs         = _joueurs
	input_handler.pieges_actifs     = pieges_actifs
	input_handler.on_rafraichir_hud = _rafraichir_hud

	# --- Sort UI ---
	if sort_ui != null:
		sort_ui.joueur_actif  = tour_manager.get_joueur_actif()
		sort_ui.input_handler = input_handler
		sort_ui.renderer      = renderer


func _connecter_signaux() -> void:
	for joueur in _joueurs:
		joueur.mort.connect(_on_joueur_mort.bind(joueur))

	tour_manager.tour_change.connect(_on_tour_change)
	tour_manager.phase_boutique.connect(_on_phase_boutique)
	tour_manager.tour_global_termine.connect(_on_tour_global_termine)

	shop_ui.boutique_fermee.connect(_on_boutique_fermee)

	event_manager.evenement_declenche.connect(_on_evenement_declenche)
	event_manager.piece_ramassee.connect(_on_piece_ramassee)
	event_manager.coffre_ramasse.connect(_on_coffre_ramasse)

	inventory_ui.bombe_demande_cible.connect(input_handler.activer_mode_bombe)
	inventory_ui.cape_utilisee.connect(input_handler.activer_mode_cape_foret)
	inventory_ui.bandage_utilise.connect(input_handler.appliquer_bandage)
	inventory_ui.fleches_utilisees.connect(input_handler.appliquer_fleches_empoisonnees)
	inventory_ui.potion_utilisee.connect(input_handler.appliquer_potion)


# =======================================================
# FIN DE TOUR
# =======================================================
func fin_de_tour() -> void:
	input_handler._reset_selection()
	renderer.sort_selectionne = -1

	var joueur_qui_finit : Node = tour_manager.get_joueur_actif()

	if joueur_qui_finit.est_place:
		effects_handler.appliquer_effets_persistants(joueur_qui_finit)

	# FORÊTS TEMPORAIRES
	var forets_a_supprimer : Array = []
	for foret in forets_temporaires:
		if foret["lanceur"] == joueur_qui_finit:
			foret["tours_restants"] -= 1
			if foret["tours_restants"] <= 0:
				forets_a_supprimer.append(foret)
	for foret in forets_a_supprimer:
		forets_temporaires.erase(foret)
		effects_handler.restaurer_cases_foret(foret)

	# MURS TEMPORAIRES
	var murs_a_supprimer : Array = []
	for mur in murs_temporaires:
		if mur["lanceur"] == joueur_qui_finit:
			mur["tours_restants"] -= 1
			if mur["tours_restants"] <= 0:
				murs_a_supprimer.append(mur)
	for mur in murs_a_supprimer:
		murs_temporaires.erase(mur)
		board.plateau[mur["x"]][mur["y"]] = mur["type_original"]
	renderer.queue_redraw()

	# MARQUE DÉROBADE
	if joueur_qui_finit.get("marque_cible") != null:
		joueur_qui_finit.marque_tours_restants -= 1
		if joueur_qui_finit.marque_tours_restants <= 0:
			joueur_qui_finit.marque_cible = null

	tour_manager.passer_au_tour_suivant()
	var joueur_suivant : Node = tour_manager.get_joueur_actif()

	# MÉTÉORES
	var meteores_a_exploser : Array = []
	for meteore in meteores_en_attente:
		if meteore["lanceur"] == joueur_suivant:
			meteore["tours_restants"] -= 1
			if meteore["tours_restants"] <= 0:
				meteores_a_exploser.append(meteore)
	for meteore in meteores_a_exploser:
		sort_handler.exploser_meteore(meteore)
		meteores_en_attente.erase(meteore)

	renderer.joueur_actif       = joueur_suivant
	renderer.joueur_selectionne = false
	renderer.queue_redraw()
	_rafraichir_hud()


# =======================================================
# CALLBACKS SIGNAUX
# =======================================================

func _on_tour_global_termine(numero_tour: int) -> void:
	event_manager.verifier_tour(numero_tour)

	var cases_restaurees : Array = event_manager.reduire_inondations()
	if cases_restaurees.size() > 0:
		for case_info in cases_restaurees:
			var j : Node = _get_joueur_en(case_info["x"], case_info["y"])
			if j:
				effects_handler.appliquer_effet_case(j)

	var laves_a_supprimer : Array = []
	for lave in laves_temporaires:
		lave["tours_restants"] -= 1
		print("🔥 Lave — %d tour(s) restant(s)" % lave["tours_restants"])
		if lave["tours_restants"] <= 0:
			effects_handler.restaurer_cases_lave(lave)
			laves_a_supprimer.append(lave)
	for lave in laves_a_supprimer:
		laves_temporaires.erase(lave)

	renderer.queue_redraw()
	_mettre_a_jour_sorts_debloques()


func _on_phase_boutique(_numero_tour: int) -> void:
	_index_joueur_boutique         = 0
	input_handler.boutique_ouverte = true
	shop_manager.ouvrir_boutique()
	shop_ui.ouvrir(joueur1)


func _on_boutique_fermee() -> void:
	_index_joueur_boutique += 1
	if _index_joueur_boutique < _joueurs.size():
		shop_ui.ouvrir(_joueurs[_index_joueur_boutique])
	else:
		input_handler.boutique_ouverte = false
		print("=== Phase boutique terminée — La partie reprend ===")


func _on_joueur_mort(joueur: Node) -> void:
	board.liberer_case(joueur.grid_x, joueur.grid_y)
	renderer.queue_redraw()
	_verifier_victoire()


func _verifier_victoire() -> void:
	var survivants : Array = _joueurs.filter(
		func(j: Node) -> bool:
			return j.est_place and not j.est_mort
	)

	if survivants.size() > 1:
		return

	if survivants.size() == 1:
		var vainqueur : Node = survivants[0]
		input_handler.boutique_ouverte = true
		game_over_ui.afficher(vainqueur)
		return

	input_handler.boutique_ouverte = true
	_label_titre_si_nul()


func _label_titre_si_nul() -> void:
	game_over_ui._label_titre.text = "💀 Match nul — Tous éliminés !"
	game_over_ui.visible = true


func _on_evenement_declenche(nom: String) -> void:
	match nom:
		"tempete":
			for j in _joueurs:
				if not j.est_mort:
					j.pm_malus_prochain_tour = 1
			_rafraichir_hud()
		"inondation":
			for j in _joueurs:
				if j.est_place and not j.est_mort:
					if board.get_case(j.grid_x, j.grid_y) == board.CaseType.EAU:
						effects_handler.appliquer_effet_case(j)
			renderer.queue_redraw()
			_rafraichir_hud()


func _on_piece_ramassee(_joueur: Node, _gold: int) -> void:
	_rafraichir_hud()
	renderer.queue_redraw()


func _on_coffre_ramasse(_joueur: Node, _gold: int) -> void:
	_rafraichir_hud()
	renderer.queue_redraw()


# =======================================================
# CALLBACKS GLOBAUX
# =======================================================

func _rafraichir_hud() -> void:
	hud_ui.rafraichir(_joueurs, tour_manager.get_joueur_actif())


# =======================================================
# HELPERS
# =======================================================

func _on_tour_change(joueur: Node) -> void:
	hud_ui.rafraichir(_joueurs, joueur)
	if sort_ui != null:
		sort_ui.joueur_actif = joueur
		sort_ui.rafraichir()


func _mettre_a_jour_sorts_debloques() -> void:
	var tour : int = tour_manager.tour_global
	var nb   : int = min(4, 1 + (tour - 1) / 2)

	for joueur in _joueurs:
		if joueur.sorts_debloques != nb:
			joueur.sorts_debloques = nb
			print("🔓 %s — %d sort(s) débloqué(s) (tour global %d)" % [joueur.name, nb, tour])

	if sort_ui != null:
		sort_ui.rafraichir()


func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in _joueurs:
		var est_actif : bool = joueur.est_place and not joueur.est_mort
		if est_actif and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null
