extends Node

# -----------------------------------------------
# JOUEUR — Classe de base
# -----------------------------------------------

var grid_x: int = 0
var grid_y: int = 0

# Indique si le joueur a été placé sur le plateau
var est_place: bool = false

var pm_max: int = 5
var pm_actuels: int = 5

var hp_max: int = 100
var hp_actuels: int = 100

var gold: int = 0
var niveau: int = 1

# -----------------------------------------------
# Place le joueur sur une case de la grille
# -----------------------------------------------
func placer(x: int, y: int):
	grid_x = x
	grid_y = y
	est_place = true  # Le joueur est maintenant sur le plateau

# -----------------------------------------------
# Retourne true si le joueur peut encore bouger
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
	var distance = abs(x - grid_x) + abs(y - grid_y)
	return distance <= pm_actuels

# -----------------------------------------------
# Déplace le joueur et consomme les PM nécessaires
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
# Overridé dans chaque classe fille (polymorphisme)
# -----------------------------------------------
func utiliser_passif():
	pass
