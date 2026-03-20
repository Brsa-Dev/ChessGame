# =======================================================
# main.gd
# -------------------------------------------------------
# Responsabilité : coordination et injection de dépendances.
#
# Ce fichier gère :
#   - Initialisation de tous les systèmes dans _ready()
#   - Injection des références dans les handlers
#   - Connexion de tous les signaux
#   - Coordination de fin_de_tour() et des callbacks
#
# Ne gère PAS : logique de gameplay (tout est dans Handlers/).
# =======================================================
extends Node2D


# =======================================================
# CONSTANTES
# =======================================================

const MAX_SORTS_DEBLOQUES    : int = 4  # Nombre maximum de sorts débloqués par joueur
const INTERVAL_DEBLOCAGE_SORT: int = 2  # Tours globaux entre chaque déblocage de sort
const TEMPETE_MALUS_PM       : int = 1  # PM retirés au prochain tour lors d'une Tempête


# =======================================================
# RÉFÉRENCES — Nœuds de la scène
# =======================================================

@onready var board           : Node      = $Board
@onready var renderer        : Node      = $Renderer
@onready var joueur1         : Node      = $Joueur1
@onready var joueur2         : Node      = $Joueur2
@onready var joueur3         : Node      = $Joueur3
@onready var tour_manager    : Node      = $TourManager
@onready var shop_manager    : Node      = $ShopManager
@onready var shop_ui         : Node      = $UI/ShopUI
@onready var event_manager   : Node      = $EventManager
@onready var hud_ui          : Node      = $UI/HudUI
@onready var inventory_ui    : Node      = $UI/InventoryUI
@onready var game_over_ui    : Node      = $UI/GameOverUi
@onready var camera          : Camera3D  = $Camera3D
@onready var sort_ui         : Node      = $UI/SortUI
@onready var timer_ui        : Node      = $UI/TimerUI
@onready var tour_ui         : Node      = $UI/TourUI
@onready var annonce_ui      : Node      = $UI/AnnonceUI
@onready var log_ui          : Node      = $UI/LogUI


# =======================================================
# RÉFÉRENCES — Handlers
# =======================================================

@onready var effects_handler : Node = $Handlers/EffectsHandler
@onready var sort_handler    : Node = $Handlers/SortHandler
@onready var input_handler   : Node = $Handlers/InputHandler


# =======================================================
# ÉTAT INTERNE
# =======================================================

# Liste centralisée des joueurs — construite dans _ready()
var _joueurs : Array[Node] = []

# Index du joueur en train de faire ses achats pendant la phase boutique
var _index_joueur_boutique : int = 0

# Listes d'état partagées entre handlers et main
var meteores_en_attente : Array[Dictionary] = []
var laves_temporaires   : Array[Dictionary] = []
var pieges_actifs       : Array[Dictionary] = []
var forets_temporaires  : Array[Dictionary] = []
var murs_temporaires    : Array[Dictionary] = []


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
	renderer.rafraichir()
	if sort_ui != null:
		sort_ui.rafraichir()

	$Camera3D.position = Vector3(10.0, 10.0, 10.0)
	$Camera3D.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)


func _initialiser_systemes() -> void:
	renderer.board         = board
	renderer.joueurs       = _joueurs
	renderer.event_manager = event_manager

	hud_ui.tour_manager = tour_manager
	hud_ui.board        = board
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
	sort_handler.board               = board
	sort_handler.renderer            = renderer
	sort_handler.event_manager       = event_manager
	sort_handler.effects_handler     = effects_handler
	sort_handler.joueurs             = _joueurs
	sort_handler.meteores_en_attente = meteores_en_attente
	sort_handler.laves_temporaires   = laves_temporaires
	sort_handler.forets_temporaires  = forets_temporaires
	sort_handler.pieges_actifs       = pieges_actifs
	sort_handler.murs_temporaires    = murs_temporaires

	# --- Input Handler ---
	input_handler.board             = board
	input_handler.renderer          = renderer
	input_handler.tour_manager      = tour_manager
	input_handler.hud_ui            = hud_ui
	input_handler.event_manager     = event_manager
	input_handler.inventory_ui      = inventory_ui
	input_handler.sort_handler      = sort_handler
	input_handler.effects_handler   = effects_handler
	input_handler.joueurs           = _joueurs
	input_handler.pieges_actifs     = pieges_actifs
	input_handler.on_rafraichir_hud = _rafraichir_hud
	input_handler.sort_ui           = sort_ui

	# --- Timer / Tour / Log UI ---
	if timer_ui != null:
		timer_ui.tour_manager = tour_manager

	if tour_ui != null:
		tour_ui._joueurs = _joueurs

	if log_ui != null:
		log_ui.joueurs = _joueurs

	sort_handler.log_ui    = log_ui
	effects_handler.log_ui = log_ui
	input_handler.on_log   = _log
	inventory_ui.on_log    = _log
	shop_manager.on_log    = _log

	# --- Sort UI ---
	if sort_ui != null:
		sort_ui.joueur_actif  = tour_manager.get_joueur_actif()
		sort_ui.input_handler = input_handler
		sort_ui.renderer      = renderer
		sort_ui.tour_manager  = tour_manager


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
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Appelée par le bouton "Fin de tour" (sort_ui) via call_group.
# Applique les effets de fin de tour du joueur actif,
# résout les effets temporaires, puis passe la main.
# -------------------------------------------------------
func fin_de_tour() -> void:
	input_handler._reset_selection()
	renderer.sort_selectionne = -1

	var joueur_qui_finit : Node = tour_manager.get_joueur_actif()

	if joueur_qui_finit.est_place:
		effects_handler.appliquer_effets_persistants(joueur_qui_finit)

	# FORÊTS TEMPORAIRES — décomptées au tour du lanceur
	var forets_a_supprimer : Array[Dictionary] = []
	for foret in forets_temporaires:
		if foret["lanceur"] == joueur_qui_finit:
			foret["tours_restants"] -= 1
			if foret["tours_restants"] <= 0:
				forets_a_supprimer.append(foret)
	for foret in forets_a_supprimer:
		forets_temporaires.erase(foret)
		effects_handler.restaurer_cases_foret(foret)

	# MURS TEMPORAIRES — décomptés au tour du lanceur
	var murs_a_supprimer : Array[Dictionary] = []
	for mur in murs_temporaires:
		if mur["lanceur"] == joueur_qui_finit:
			mur["tours_restants"] -= 1
			if mur["tours_restants"] <= 0:
				murs_a_supprimer.append(mur)
	for mur in murs_a_supprimer:
		murs_temporaires.erase(mur)
		board.plateau[mur["x"]][mur["y"]] = mur["type_original"]
	renderer.rafraichir()

	# MARQUE DÉROBADE — expire après quelques tours sans explosion
	if joueur_qui_finit.get("marque_cible") != null:
		joueur_qui_finit.marque_tours_restants -= 1
		if joueur_qui_finit.marque_tours_restants <= 0:
			joueur_qui_finit.marque_cible = null

	tour_manager.passer_au_tour_suivant()
	var joueur_suivant : Node = tour_manager.get_joueur_actif()

	# MÉTÉORES — explosent au tour du lanceur (décompte démarré au lancer)
	var meteores_a_exploser : Array[Dictionary] = []
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
	renderer.rafraichir()
	_rafraichir_hud()


# =======================================================
# CALLBACKS SIGNAUX
# =======================================================

func _on_tour_change(joueur: Node) -> void:
	_mettre_a_jour_sorts_debloques()
	hud_ui.rafraichir(_joueurs, joueur)
	tour_ui.rafraichir(joueur)
	if sort_ui != null:
		sort_ui.joueur_actif = joueur
		sort_ui.rafraichir()


func _on_tour_global_termine(numero_tour: int) -> void:
	event_manager.verifier_tour(numero_tour)

	var cases_restaurees : Array[Dictionary] = event_manager.reduire_inondations()
	if cases_restaurees.size() > 0:
		for case_info in cases_restaurees:
			var j : Node = _get_joueur_en(case_info["x"], case_info["y"])
			if j:
				effects_handler.appliquer_effet_case(j)

	var laves_a_supprimer : Array[Dictionary] = []
	for lave in laves_temporaires:
		lave["tours_restants"] -= 1
		if lave["tours_restants"] <= 0:
			effects_handler.restaurer_cases_lave(lave)
			laves_a_supprimer.append(lave)
	for lave in laves_a_supprimer:
		laves_temporaires.erase(lave)

	renderer.rafraichir()
	_mettre_a_jour_sorts_debloques()


func _on_phase_boutique(_numero_tour: int) -> void:
	_index_joueur_boutique         = 0
	input_handler.boutique_ouverte = true
	shop_manager.ouvrir_boutique()
	shop_ui.ouvrir(joueur1)
	if sort_ui != null:
		sort_ui.set_fin_tour_actif(false)


func _on_boutique_fermee() -> void:
	_index_joueur_boutique += 1
	if _index_joueur_boutique < _joueurs.size():
		shop_ui.ouvrir(_joueurs[_index_joueur_boutique])
	else:
		input_handler.boutique_ouverte = false
		if sort_ui != null:
			sort_ui.set_fin_tour_actif(true)


func _on_joueur_mort(joueur: Node) -> void:
	annonce_ui.afficher("💀 %s éliminé !" % joueur.name, annonce_ui.COULEUR_MORT)
	board.liberer_case(joueur.grid_x, joueur.grid_y)
	renderer.rafraichir()
	_verifier_victoire()


func _on_evenement_declenche(nom: String) -> void:
	match nom:
		"tempete":
			annonce_ui.afficher("⚡ Tempête électrique !", annonce_ui.COULEUR_EVENEMENT)
			for j in _joueurs:
				if not j.est_mort:
					j.pm_malus_prochain_tour = TEMPETE_MALUS_PM
			_rafraichir_hud()
		"inondation":
			annonce_ui.afficher("🌊 Inondation !", annonce_ui.COULEUR_EVENEMENT)
			for j in _joueurs:
				if j.est_place and not j.est_mort:
					if board.get_case(j.grid_x, j.grid_y) == board.CaseType.EAU:
						effects_handler.appliquer_effet_case(j)
			renderer.rafraichir()
			_rafraichir_hud()


func _on_piece_ramassee(_joueur: Node, _gold: int) -> void:
	_rafraichir_hud()
	renderer.rafraichir()


func _on_coffre_ramasse(_joueur: Node, _gold: int) -> void:
	_rafraichir_hud()
	renderer.rafraichir()


# =======================================================
# HELPERS
# =======================================================

func _rafraichir_hud() -> void:
	hud_ui.rafraichir(_joueurs, tour_manager.get_joueur_actif())


func _log(message: String, joueur: Node = null) -> void:
	if log_ui == null:
		return
	log_ui.ajouter(message, joueur)


# -------------------------------------------------------
# Met à jour le nombre de sorts débloqués pour chaque joueur.
# Règle : 1 sort au tour 1, +1 tous les INTERVAL_DEBLOCAGE_SORT tours globaux,
# jusqu'à MAX_SORTS_DEBLOQUES.
# -------------------------------------------------------
func _mettre_a_jour_sorts_debloques() -> void:
	var tour : int = tour_manager.tour_global
	var nb   : int = min(MAX_SORTS_DEBLOQUES, 1 + (tour - 1) / INTERVAL_DEBLOCAGE_SORT)

	for joueur in _joueurs:
		if joueur.sorts_debloques != nb:
			joueur.sorts_debloques = nb

	if sort_ui != null:
		sort_ui.rafraichir()


func _verifier_victoire() -> void:
	var survivants : Array[Node] = _joueurs.filter(
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


# -------------------------------------------------------
# Retourne le joueur vivant et placé sur la case (x, y).
# Retourne null si aucun joueur ne s'y trouve.
# -------------------------------------------------------
func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in _joueurs:
		var est_actif : bool = joueur.est_place and not joueur.est_mort
		if est_actif and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null
