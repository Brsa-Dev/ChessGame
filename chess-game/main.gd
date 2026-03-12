extends Node2D

@onready var board = $Board
@onready var renderer = $Renderer
@onready var joueur = $Joueur  # Référence directe au nœud dans la scène

var joueur_selectionne: bool = false

func _ready():
	renderer.board = board
	renderer.joueur = joueur
	renderer.queue_redraw()
	print("Main prêt !")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var cell = renderer.screen_to_grid(event.position)
		if cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 8:
			return

		if not joueur.est_place:
			joueur.placer(cell.x, cell.y)
			print("Joueur placé en (", cell.x, ", ", cell.y, ")")

		elif not joueur_selectionne:
			if cell.x == joueur.grid_x and cell.y == joueur.grid_y:
				joueur_selectionne = true
				print("Joueur sélectionné")

		else:
			if cell.x == joueur.grid_x and cell.y == joueur.grid_y:
				joueur_selectionne = false
				print("Joueur désélectionné")
			elif joueur.peut_se_deplacer_vers(cell.x, cell.y):
				joueur.deplacer(cell.x, cell.y)
				joueur_selectionne = false
				print("Joueur déplacé en (", cell.x, ", ", cell.y, ") — PM restants : ", joueur.pm_actuels)

		renderer.joueur_selectionne = joueur_selectionne
		renderer.queue_redraw()
