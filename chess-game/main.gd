extends Node2D

@onready var board = $Board
@onready var renderer = $Renderer
@onready var joueur1 = $Joueur1
@onready var joueur2 = $Joueur2
@onready var tour_manager = $TourManager
@onready var bouton_fin_tour = $UI/BoutonFinTour

var joueur_selectionne: bool = false

func _ready():
	renderer.board = board
	renderer.joueurs = [joueur1, joueur2]
	tour_manager.initialiser([joueur1, joueur2])
	renderer.joueur_actif = tour_manager.get_joueur_actif()
	bouton_fin_tour.pressed.connect(fin_de_tour)
	renderer.queue_redraw()
	print("Main prêt !")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var cell = renderer.screen_to_grid(event.position)
		var joueur_actif = tour_manager.get_joueur_actif()

		# Clic en dehors du plateau → désélection
		if cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 8:
			if joueur_selectionne:
				joueur_selectionne = false
				renderer.joueur_selectionne = false
				renderer.queue_redraw()
			return

		# Cas 1 : le joueur actif n'est pas encore placé → on le place
		if not joueur_actif.est_place:
			if not board.case_occupee(cell.x, cell.y):
				board.occuper_case(cell.x, cell.y)
				joueur_actif.placer(cell.x, cell.y)
				print("Joueur placé en (", cell.x, ", ", cell.y, ")")
			else:
				print("Case déjà occupée !")

		# Cas 2 : placé mais pas sélectionné
		# → clic sur le joueur actif = sélection
		elif not joueur_selectionne:
			if cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				if joueur_actif.peut_se_deplacer() or not joueur_actif.a_attaque_ce_tour:
					joueur_selectionne = true
					print("Joueur sélectionné — PM : ", joueur_actif.pm_actuels)
				else:
					print("Plus de PM et déjà attaqué !")

		# Cas 3 : sélectionné
		else:
			# Reclique sur soi-même → désélection
			if cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				joueur_selectionne = false
				print("Joueur désélectionné")

			# Clic sur un ennemi → attaque
			elif _get_joueur_en(cell.x, cell.y) != null:
				var cible = _get_joueur_en(cell.x, cell.y)
				if joueur_actif.peut_attaquer(cell.x, cell.y):
					joueur_actif.attaquer(cible)
					joueur_selectionne = false
					print("HP cible : ", cible.hp_actuels, "/", cible.hp_max)
				else:
					if joueur_actif.a_attaque_ce_tour:
						print("Déjà attaqué ce tour !")
					elif joueur_actif.pm_actuels < joueur_actif.attaque_cout_pm:
						print("Pas assez de PM pour attaquer !")
					else:
						print("Cible hors de portée !")

			# Clic sur une case libre → déplacement
			elif joueur_actif.peut_se_deplacer_vers(cell.x, cell.y):
				if not board.case_occupee(cell.x, cell.y):
					board.liberer_case(joueur_actif.grid_x, joueur_actif.grid_y)
					joueur_actif.deplacer(cell.x, cell.y)
					board.occuper_case(joueur_actif.grid_x, joueur_actif.grid_y)
					joueur_selectionne = false
					print("Déplacé en (", cell.x, ", ", cell.y, ") — PM : ", joueur_actif.pm_actuels)
					if not joueur_actif.peut_se_deplacer():
						print("Plus de PM !")
				else:
					print("Case occupée !")
			else:
				print("Case inaccessible !")

		renderer.joueur_actif = joueur_actif
		renderer.joueur_selectionne = joueur_selectionne
		renderer.queue_redraw()

# Retourne le joueur situé sur la case (x, y), ou null si vide
func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in [joueur1, joueur2]:
		if joueur.est_place and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null

# Appelée par le bouton "Fin de tour"
func fin_de_tour():
	joueur_selectionne = false
	tour_manager.passer_au_tour_suivant()
	var joueur_actif = tour_manager.get_joueur_actif()
	print("--- Tour du Joueur ", tour_manager.index_joueur_actif + 1, " ---")
	renderer.joueur_actif = joueur_actif
	renderer.joueur_selectionne = false
	renderer.queue_redraw()
