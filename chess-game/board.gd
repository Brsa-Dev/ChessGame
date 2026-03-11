extends Node

enum CaseType {
	NORMAL, LAVE, EAU, VIDE, FORET, MUR, TOUR
}

var plateau = []

func _ready():
	init_plateau()

func init_plateau():
	for x in range(8):
		plateau.append([])
		for y in range(8):
			plateau[x].append(CaseType.NORMAL)
	print("Plateau initialisé !")
