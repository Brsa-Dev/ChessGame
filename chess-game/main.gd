extends Node2D

@onready var board = $Board
@onready var renderer = $Renderer
@onready var joueur = $Joueur

var joueur_selectionne: bool = false

func _ready():
	renderer.board = board
	renderer.joueur = joueur
	renderer.queue_redraw()
	print("Main prêt !")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var cell = renderer.screen_to_grid(event.position)
		
		# Clic en dehors du plateau → on désélectionne le joueur
		if cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 8:
			if joueur_selectionne:
				joueur_selectionne = false
				print("Joueur désélectionné")
				renderer.joueur_selectionne = joueur_selectionne
				renderer.queue_redraw()
			return
		
		# Cas 1 : le joueur n'est pas encore placé → on le place
		if not joueur.est_place:
			joueur.placer(cell.x, cell.y)
			print("Joueur placé en (", cell.x, ", ", cell.y, ")")
		
		# Cas 2 : le joueur est placé mais pas sélectionné
		elif not joueur_selectionne:
			if cell.x == joueur.grid_x and cell.y == joueur.grid_y:
				# On vérifie les PM avant de sélectionner
				if joueur.peut_se_deplacer():
					joueur_selectionne = true
					print("Joueur sélectionné — PM restants : ", joueur.pm_actuels)
				else:
					print("Plus de PM ! Impossible de se déplacer.")
		
		# Cas 3 : le joueur est sélectionné
		else:
			# Reclique sur le joueur → désélection
			if cell.x == joueur.grid_x and cell.y == joueur.grid_y:
				joueur_selectionne = false
				print("Joueur désélectionné")
			# Clic sur une case accessible → déplacement
			elif joueur.peut_se_deplacer_vers(cell.x, cell.y):
				joueur.deplacer(cell.x, cell.y)
				joueur_selectionne = false
				print("Joueur déplacé en (", cell.x, ", ", cell.y, ") — PM restants : ", joueur.pm_actuels)
				# Si plus de PM après le déplacement, on prévient
				if not joueur.peut_se_deplacer():
					print("Plus de PM !")
			# Clic sur une case inaccessible
			else:
				print("Case inaccessible !")
		
		renderer.joueur_selectionne = joueur_selectionne
		renderer.queue_redraw()
