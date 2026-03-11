# board.gd
# Ce fichier est le "cerveau" du plateau.
# Il ne gère que les données, pas l'affichage.

extends Node

# Liste de tous les types de cases possibles dans le jeu
enum CaseType {
	NORMAL,
	LAVE,
	EAU,
	VIDE,
	FORET,
	MUR,
	TOUR
}

# Le plateau : un tableau 2D de 8x8 cases
# Chaque case contient son type (CaseType)
var plateau = []

func _ready():
	init_plateau()

# Crée le plateau et met toutes les cases en NORMAL par défaut
func init_plateau():
	for x in range(8):
		plateau.append([])      # Ajoute une colonne
		for y in range(8):
			plateau[x].append(CaseType.NORMAL)  # Chaque case = NORMAL

	print("Plateau initialisé !")
	print("Type de la case (0,0) : ", CaseType.keys()[plateau[0][0]])
