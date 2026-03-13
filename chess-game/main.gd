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
@onready var board           : Node = $Board
@onready var renderer        : Node = $Renderer
@onready var joueur1         : Node = $Joueur1
@onready var joueur2         : Node = $Joueur2
@onready var joueur3         : Node = $Joueur3
@onready var tour_manager    : Node = $TourManager
@onready var shop_manager    : Node = $ShopManager
@onready var shop_ui         : Node = $ShopUI
@onready var event_manager   : Node = $EventManager
@onready var log_ui          : Node = $UI/LogUI
@onready var hud_ui          : Node = $HudUI
@onready var inventory_ui    : Node = $InventoryUI
@onready var bouton_fin_tour : Node = $UI/BoutonFinTour

# -------------------------------------------------------
# Références aux handlers (nœuds enfants dans main.tscn)
# -------------------------------------------------------
@onready var effects_handler : Node = $Handlers/EffectsHandler
@onready var sort_handler    : Node = $Handlers/SortHandler
@onready var input_handler   : Node = $Handlers/InputHandler

# -------------------------------------------------------
# Liste centralisée des joueurs — construite dans _ready()
# -------------------------------------------------------
var _joueurs : Array = []

# Index du joueur en cours d'achat pendant la phase boutique
var _index_joueur_boutique : int = 0

# -------------------------------------------------------
# Listes d'état partagées entre handlers et main
# -------------------------------------------------------
var meteores_en_attente : Array = []  # Météores en vol
var laves_temporaires   : Array = []  # Cases de lave actives (Météore)
var pieges_actifs       : Array = []  # Pièges posés sur le plateau
var forets_temporaires  : Array = []  # Forêts temporaires actives


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	_joueurs = [joueur1, joueur2, joueur3]

	_initialiser_systemes()
	_injecter_references_handlers()
	_connecter_signaux()
	_positionner_bouton_fin_tour()

	hud_ui.rafraichir(_joueurs, tour_manager.get_joueur_actif())
	renderer.queue_redraw()
	print("✅ Main prêt !")


# -------------------------------------------------------
# Initialise les systèmes qui ont besoin de références
# avant de pouvoir être utilisés
# -------------------------------------------------------
func _initialiser_systemes() -> void:
	renderer.board         = board
	renderer.joueurs       = _joueurs
	renderer.event_manager = event_manager

	hud_ui.board        = board
	event_manager.board = board

	# TourManager doit être initialisé avant tout appel à get_joueur_actif()
	tour_manager.initialiser(_joueurs)
	renderer.joueur_actif = tour_manager.get_joueur_actif()

	shop_ui.shop_manager = shop_manager


# -------------------------------------------------------
# Injecte les références dans les 3 handlers.
# Chaque handler reçoit uniquement ce dont il a besoin.
# -------------------------------------------------------
func _injecter_references_handlers() -> void:
	# --- Effects Handler ---
	effects_handler.board    = board
	effects_handler.renderer = renderer
	effects_handler.log_ui   = log_ui
	effects_handler.joueurs  = _joueurs

	# --- Sort Handler ---
	sort_handler.board           = board
	sort_handler.renderer        = renderer
	sort_handler.log_ui          = log_ui
	sort_handler.event_manager   = event_manager
	sort_handler.effects_handler = effects_handler
	sort_handler.joueurs         = _joueurs
	# Listes partagées — le sort_handler les lit ET les modifie
	sort_handler.meteores_en_attente = meteores_en_attente
	sort_handler.laves_temporaires   = laves_temporaires
	sort_handler.forets_temporaires  = forets_temporaires
	sort_handler.pieges_actifs       = pieges_actifs

	# --- Input Handler ---
	input_handler.board           = board
	input_handler.renderer        = renderer
	input_handler.tour_manager    = tour_manager
	input_handler.log_ui          = log_ui
	input_handler.hud_ui          = hud_ui
	input_handler.event_manager   = event_manager
	input_handler.inventory_ui    = inventory_ui
	input_handler.sort_handler    = sort_handler
	input_handler.effects_handler = effects_handler
	input_handler.joueurs         = _joueurs
	input_handler.pieges_actifs   = pieges_actifs
	# Callbacks — évite le couplage direct entre input_handler et main
	input_handler.on_log            = _log
	input_handler.on_rafraichir_hud = _rafraichir_hud


# -------------------------------------------------------
# Connecte tous les signaux du jeu
# -------------------------------------------------------
func _connecter_signaux() -> void:
	bouton_fin_tour.pressed.connect(fin_de_tour)

	for joueur in _joueurs:
		joueur.mort.connect(_on_joueur_mort.bind(joueur))

	tour_manager.phase_boutique.connect(_on_phase_boutique)
	tour_manager.tour_global_termine.connect(_on_tour_global_termine)

	shop_ui.boutique_fermee.connect(_on_boutique_fermee)

	event_manager.evenement_declenche.connect(_on_evenement_declenche)
	event_manager.piece_ramassee.connect(_on_piece_ramassee)
	event_manager.coffre_ramasse.connect(_on_coffre_ramasse)

	# Signaux de l'inventaire → input_handler
	# Chaque signal correspond à un item utilisable manuellement
	inventory_ui.bombe_demande_cible.connect(input_handler.activer_mode_bombe)
	inventory_ui.cape_utilisee.connect(input_handler.activer_mode_cape_foret)
	inventory_ui.bandage_utilise.connect(input_handler.appliquer_bandage)
	inventory_ui.fleches_utilisees.connect(input_handler.appliquer_fleches_empoisonnees)


# -------------------------------------------------------
# Positionne le bouton Fin de Tour en bas au centre
# -------------------------------------------------------
func _positionner_bouton_fin_tour() -> void:
	var taille_ecran : Vector2 = get_viewport().get_visible_rect().size
	bouton_fin_tour.set_position(Vector2(
		(taille_ecran.x / 2.0) - 55.0,
		taille_ecran.y - 45.0
	))


# =======================================================
# FIN DE TOUR
# -------------------------------------------------------
# Coordonne toutes les actions de fin de tour :
# effets persistants, météores, forêts temporaires,
# passage au tour suivant, et rafraîchissement visuel.
# =======================================================
func fin_de_tour() -> void:
	input_handler._reset_selection()
	renderer.sort_selectionne = -1

	var joueur_qui_finit : Node = tour_manager.get_joueur_actif()

	# Effets de case persistants (lave/eau) en fin de tour
	if joueur_qui_finit.est_place:
		effects_handler.appliquer_effets_persistants(joueur_qui_finit)

	# -------------------------------------------------------
	# FORÊTS TEMPORAIRES
	# Décrémentées uniquement au tour du lanceur
	# -------------------------------------------------------
	var forets_a_supprimer : Array = []
	for foret in forets_temporaires:
		if foret["lanceur"] == joueur_qui_finit:
			foret["tours_restants"] -= 1
			print("🌲 Forêt temp — %d tour(s) restant(s)" % foret["tours_restants"])
			if foret["tours_restants"] <= 0:
				forets_a_supprimer.append(foret)
	for foret in forets_a_supprimer:
		forets_temporaires.erase(foret)
		effects_handler.restaurer_cases_foret(foret)

	# -------------------------------------------------------
	# MÉTÉORES
	# Décrémentés uniquement au tour du lanceur
	# -------------------------------------------------------
	var meteores_a_exploser : Array = []
	for meteore in meteores_en_attente:
		if meteore["lanceur"] == joueur_qui_finit:
			meteore["tours_restants"] -= 1
			print("☄️ Météore — %d tour(s) restant(s)" % meteore["tours_restants"])
			if meteore["tours_restants"] <= 0:
				meteores_a_exploser.append(meteore)
	for meteore in meteores_a_exploser:
		sort_handler.exploser_meteore(meteore)
		meteores_en_attente.erase(meteore)

	tour_manager.passer_au_tour_suivant()
	var joueur_suivant : Node = tour_manager.get_joueur_actif()

	# -------------------------------------------------------
	# MARQUE DÉROBADE
	# Décrémentée au tour du Fripon lanceur
	# -------------------------------------------------------
	if joueur_qui_finit.get("marque_cible") != null:
		joueur_qui_finit.marque_tours_restants -= 1
		print("🎯 Marque — %d tour(s) avant expiration" % joueur_qui_finit.marque_tours_restants)
		if joueur_qui_finit.marque_tours_restants <= 0:
			joueur_qui_finit.marque_cible = null
			print("🎯 Marque expirée sans dégâts")

	_log("--- Tour de %s ---" % joueur_suivant.name)
	renderer.joueur_actif       = joueur_suivant
	renderer.joueur_selectionne = false
	renderer.queue_redraw()
	_rafraichir_hud()


# =======================================================
# CALLBACKS SIGNAUX
# =======================================================

func _on_tour_global_termine(numero_tour: int) -> void:
	event_manager.verifier_tour(numero_tour)

	# Restaure les cases inondées expirées
	var cases_restaurees : Array = event_manager.reduire_inondations()
	if cases_restaurees.size() > 0:
		for case_info in cases_restaurees:
			var j : Node = _get_joueur_en(case_info["x"], case_info["y"])
			if j:
				effects_handler.appliquer_effet_case(j)
		_log("🍂 === Les cases inondées sont restaurées ===")

	# Décrémente et restaure les laves temporaires (Météore)
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


func _on_phase_boutique(_numero_tour: int) -> void:
	_index_joueur_boutique         = 0
	input_handler.boutique_ouverte = true
	shop_manager.ouvrir_boutique()
	bouton_fin_tour.disabled = true
	shop_ui.ouvrir(joueur1)


func _on_boutique_fermee() -> void:
	_index_joueur_boutique += 1
	if _index_joueur_boutique < _joueurs.size():
		shop_ui.ouvrir(_joueurs[_index_joueur_boutique])
	else:
		input_handler.boutique_ouverte = false
		bouton_fin_tour.disabled       = false
		print("=== Phase boutique terminée — La partie reprend ===")


func _on_joueur_mort(joueur: Node) -> void:
	board.liberer_case(joueur.grid_x, joueur.grid_y)
	_log("💀 %s est éliminé !" % joueur.name)
	renderer.queue_redraw()


func _on_evenement_declenche(nom: String) -> void:
	match nom:
		"mine_or":
			_log("⛏️ === 3 Mines d'Or sont apparues ! Détruisez-les pour du Gold ===")
		"coffre":
			_log("💎 === Un Coffre au Trésor est apparu ! Marchez dessus pour le ramasser ===")
		"tempete":
			for j in _joueurs:
				if not j.est_mort:
					j.pm_malus_prochain_tour = 1
			_log("⚡ === Tempête Électrique ! Tous les joueurs perdent 1 PM ce tour ===")
			_rafraichir_hud()
		"inondation":
			for j in _joueurs:
				if j.est_place and not j.est_mort:
					if board.get_case(j.grid_x, j.grid_y) == board.CaseType.EAU:
						effects_handler.appliquer_effet_case(j)
			_log("🌊 === Inondation ! 4 cases deviennent Eau pendant 3 tours ===")
			renderer.queue_redraw()
			_rafraichir_hud()


func _on_piece_ramassee(joueur: Node, gold: int) -> void:
	_log("💰 %s ramasse un tas de pièces ! +%d Gold" % [joueur.name, gold], joueur)
	_rafraichir_hud()
	renderer.queue_redraw()


func _on_coffre_ramasse(joueur: Node, gold: int) -> void:
	_log("💎 %s ouvre le coffre ! +%d Gold" % [joueur.name, gold], joueur)
	_rafraichir_hud()
	renderer.queue_redraw()


# =======================================================
# CALLBACKS GLOBAUX
# -------------------------------------------------------
# Passés comme Callable aux handlers pour qu'ils puissent
# logger et rafraîchir le HUD sans couplage direct.
# =======================================================

func _log(message: String, joueur: Node = null) -> void:
	var couleur : Color = log_ui.COULEUR_SYSTEME
	var index   : int   = _joueurs.find(joueur)
	match index:
		0: couleur = log_ui.COULEUR_J1
		1: couleur = log_ui.COULEUR_J2
		2: couleur = log_ui.COULEUR_J3
	log_ui.ajouter(message, couleur)


func _rafraichir_hud() -> void:
	hud_ui.rafraichir(_joueurs, tour_manager.get_joueur_actif())


# =======================================================
# HELPERS
# =======================================================

func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in _joueurs:
		var est_actif : bool = joueur.est_place and not joueur.est_mort
		if est_actif and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null
