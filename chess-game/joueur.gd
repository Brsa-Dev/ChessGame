extends Node

# -----------------------------------------------
# JOUEUR — Classe de base
# Contient toutes les données communes à tous les joueurs.
# Les classes spécifiques (Guerrier, Mage, etc.)
# hériteront de ce script plus tard.
# -----------------------------------------------

# Position du joueur sur la grille
var grid_x: int = 0
var grid_y: int = 0

# Points de mouvement
var pm_max: int = 5
var pm_actuels: int = 5

# Points de vie
var hp_max: int = 100
var hp_actuels: int = 100

# Gold
var gold: int = 0

# Niveau (commence à 1, max 9)
var niveau: int = 1

# -----------------------------------------------
# Place le joueur sur une case de la grille
# -----------------------------------------------
func placer(x: int, y: int):
	grid_x = x
	grid_y = y

# -----------------------------------------------
# Retourne true si le joueur peut encore se déplacer
# -----------------------------------------------
func peut_se_deplacer() -> bool:
	return pm_actuels > 0

# -----------------------------------------------
# Vérifie si la case (x, y) est accessible :
# - adjacente (pas de diagonale)
# - à portée des PM restants
# -----------------------------------------------
func peut_se_deplacer_vers(x: int, y: int) -> bool:
	if not peut_se_deplacer():
		return false
	# Distance de Manhattan : somme des écarts en x et en y
	# Ex: (3,4) → (3,5) = 1 case, (3,4) → (4,5) = 2 cases (diagonale, refusée)
	var distance = abs(x - grid_x) + abs(y - grid_y)
	return distance <= pm_actuels
	
# -----------------------------------------------
# Déplace le joueur sur la case (x, y)
# et consomme 1 PM
# -----------------------------------------------
func deplacer(x: int, y: int):
	if peut_se_deplacer_vers(x, y):
		var distance = abs(x - grid_x) + abs(y - grid_y)
		pm_actuels -= distance
		grid_x = x
		grid_y = y

# -----------------------------------------------
# Réinitialise les PM au début de chaque tour
# -----------------------------------------------
func debut_tour():
	pm_actuels = pm_max

# -----------------------------------------------
# Appelée par les sous-classes pour définir
# leur effet passif (polymorphisme)
# -----------------------------------------------
func utiliser_passif():
	pass  # Overridé dans chaque classe fille
