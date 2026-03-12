extends Node2D

@onready var board = $Board
@onready var renderer = $Renderer
@onready var joueur1 = $Joueur1
@onready var joueur2 = $Joueur2
@onready var tour_manager = $TourManager

var joueur_selectionne: bool = false

func _ready():
	# Connexion board → renderer
	renderer.board = board
	
	# On donne les deux joueurs au renderer
	renderer.joueurs = [joueur1, joueur2]
	
	# On donne les deux joueurs au tour_manager
	tour_manager.initialiser([joueur1, joueur2])
	
	# On assigne immédiatement le joueur actif au renderer
	# AVANT le premier queue_redraw() pour éviter le crash
	renderer.joueur_actif = tour_manager.get_joueur_actif()
	
	renderer.queue_redraw()
	print("Main prêt !")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var cell = renderer.screen_to_grid(event.position)
		
		# On récupère le joueur dont c'est le tour
		var joueur_actif = tour_manager.get_joueur_actif()
		
		# Clic en dehors du plateau → désélection
		if cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 8:
			if joueur_selectionne:
				joueur_selectionne = false
				renderer.joueur_selectionne = joueur_selectionne
				renderer.queue_redraw()
			return
		
		# Cas 1 : le joueur actif n'est pas encore placé → on le place
		if not joueur_actif.est_place:
			joueur_actif.placer(cell.x, cell.y)
			print("Joueur placé en (", cell.x, ", ", cell.y, ")")
		
		# Cas 2 : placé mais pas sélectionné
		elif not joueur_selectionne:
			if cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				if joueur_actif.peut_se_deplacer():
					joueur_selectionne = true
					print("Joueur sélectionné — PM restants : ", joueur_actif.pm_actuels)
				else:
					print("Plus de PM !")
		
		# Cas 3 : sélectionné
		else:
			if cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				joueur_selectionne = false
				print("Joueur désélectionné")
			elif joueur_actif.peut_se_deplacer_vers(cell.x, cell.y):
				joueur_actif.deplacer(cell.x, cell.y)
				joueur_selectionne = false
				print("Joueur déplacé en (", cell.x, ", ", cell.y, ") — PM restants : ", joueur_actif.pm_actuels)
				if not joueur_actif.peut_se_deplacer():
					print("Plus de PM !")
			else:
				print("Case inaccessible !")
		
		renderer.joueur_actif = joueur_actif
		renderer.joueur_selectionne = joueur_selectionne
		renderer.queue_redraw()

# Appelée par le bouton "Fin de tour" ou par le timer
func fin_de_tour():
	joueur_selectionne = false
	tour_manager.passer_au_tour_suivant()
	var joueur_actif = tour_manager.get_joueur_actif()
	print("Tour du joueur : ", tour_manager.index_joueur_actif + 1)
	renderer.joueur_actif = joueur_actif
	renderer.joueur_selectionne = false
	renderer.queue_redraw()
