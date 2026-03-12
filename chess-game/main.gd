extends Node2D

@onready var board = $Board
@onready var renderer = $Renderer
@onready var joueur1 = $Joueur1
@onready var joueur2 = $Joueur2
@onready var tour_manager = $TourManager
@onready var bouton_fin_tour = $UI/BoutonFinTour

# --- NOUVEAU — références boutique ---
@onready var shop_manager = $ShopManager
@onready var shop_ui = $ShopUI

var joueur_selectionne: bool = false

# Index du joueur en train d'acheter pendant la phase boutique
var index_joueur_boutique: int = 0

func _ready():
	renderer.board = board
	renderer.joueurs = [joueur1, joueur2]
	tour_manager.initialiser([joueur1, joueur2])
	renderer.joueur_actif = tour_manager.get_joueur_actif()
	bouton_fin_tour.pressed.connect(fin_de_tour)
	
	joueur1.mort.connect(_on_joueur_mort.bind(joueur1))
	joueur2.mort.connect(_on_joueur_mort.bind(joueur2))
	
	# --- NOUVEAU — on connecte le signal phase_boutique ---
	tour_manager.phase_boutique.connect(_on_phase_boutique)
	
	# --- NOUVEAU — quand un joueur ferme la boutique ---
	shop_ui.boutique_fermee.connect(_on_boutique_fermee)
	
	# --- NOUVEAU — on donne le shop_manager au shop_ui ---
	shop_ui.shop_manager = shop_manager
	
	renderer.queue_redraw()
	print("Main prêt !")

# -----------------------------------------------
# Appelée par tour_manager quand un tour global se termine
# Lance la phase boutique pour le Joueur 1 en premier
# -----------------------------------------------
func _on_phase_boutique(_numero_tour: int):
	index_joueur_boutique = 0
	shop_manager.ouvrir_boutique()
	# On bloque le bouton fin de tour pendant la boutique
	bouton_fin_tour.disabled = true
	# On ouvre la boutique pour le premier joueur
	shop_ui.ouvrir(joueur1)

# -----------------------------------------------
# Appelée quand un joueur clique "Passer" dans la boutique
# Passe au joueur suivant, ou ferme la boutique si tout le monde a acheté
# -----------------------------------------------
func _on_boutique_fermee():
	index_joueur_boutique += 1
	
	if index_joueur_boutique < 2:
		# C'est au tour du Joueur 2
		shop_ui.ouvrir(joueur2)
	else:
		# Les deux joueurs ont eu leur tour → on reprend la partie
		bouton_fin_tour.disabled = false
		print("=== Phase boutique terminée — La partie reprend ===")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var cell = renderer.screen_to_grid(event.position)
		var joueur_actif = tour_manager.get_joueur_actif()

		if cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 8:
			if joueur_selectionne:
				joueur_selectionne = false
				renderer.joueur_selectionne = false
				renderer.queue_redraw()
			return

		if not joueur_actif.est_place:
			if not board.case_occupee(cell.x, cell.y):
				board.occuper_case(cell.x, cell.y)
				joueur_actif.placer(cell.x, cell.y)
				print("Joueur placé en (", cell.x, ", ", cell.y, ")")
			else:
				print("Case déjà occupée !")

		elif not joueur_selectionne:
			if cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				if joueur_actif.peut_se_deplacer() or not joueur_actif.a_attaque_ce_tour:
					joueur_selectionne = true
					print("Joueur sélectionné — PM : ", joueur_actif.pm_actuels)
				else:
					print("Plus de PM et déjà attaqué !")

		else:
			if cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				joueur_selectionne = false
				print("Joueur désélectionné")

			elif _get_joueur_en(cell.x, cell.y) != null:
				var cible = _get_joueur_en(cell.x, cell.y)
				if joueur_actif.peut_attaquer(cell.x, cell.y):
					joueur_actif.attaquer(cible)
					joueur_selectionne = false
				else:
					if joueur_actif.a_attaque_ce_tour:
						print("Déjà attaqué ce tour !")
					elif joueur_actif.pm_actuels < joueur_actif.attaque_cout_pm:
						print("Pas assez de PM !")
					else:
						print("Cible hors de portée !")

			elif joueur_actif.peut_se_deplacer_vers(cell.x, cell.y):
				if not board.case_occupee(cell.x, cell.y):
					board.liberer_case(joueur_actif.grid_x, joueur_actif.grid_y)
					joueur_actif.deplacer(cell.x, cell.y)
					board.occuper_case(joueur_actif.grid_x, joueur_actif.grid_y)
					joueur_selectionne = false
					print("Déplacé en (", cell.x, ", ", cell.y, ") — PM : ", joueur_actif.pm_actuels)
				else:
					print("Case occupée !")
			else:
				print("Case inaccessible !")

		renderer.joueur_actif = joueur_actif
		renderer.joueur_selectionne = joueur_selectionne
		renderer.queue_redraw()

func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in [joueur1, joueur2]:
		if joueur.est_place and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null

func _on_joueur_mort(joueur: Node):
	board.liberer_case(joueur.grid_x, joueur.grid_y)
	renderer.queue_redraw()

func fin_de_tour():
	joueur_selectionne = false
	tour_manager.passer_au_tour_suivant()
	var joueur_actif = tour_manager.get_joueur_actif()
	print("--- Tour du Joueur ", tour_manager.index_joueur_actif + 1, " ---")
	renderer.joueur_actif = joueur_actif
	renderer.joueur_selectionne = false
	renderer.queue_redraw()
