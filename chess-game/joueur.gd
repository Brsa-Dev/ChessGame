extends Node

# -----------------------------------------------
# JOUEUR — Classe de base
# -----------------------------------------------

var grid_x: int = 0
var grid_y: int = 0
var est_place: bool = false

var pm_max: int = 5
var pm_actuels: int = 5

var hp_max: int = 100
var hp_actuels: int = 100

var gold: int = 0
var niveau: int = 1

# -----------------------------------------------
# Attaque de base — valeurs génériques
# Seront overridées par chaque classe fille
# -----------------------------------------------
var attaque_degats: int = 10        # Dégâts infligés
var attaque_portee: int = 1         # Portée en cases (distance de Manhattan)
var attaque_cout_pm: int = 1        # PM consommés par attaque
var a_attaque_ce_tour: bool = false # True si le joueur a déjà attaqué ce tour

# -----------------------------------------------
# Place le joueur sur une case de la grille
# -----------------------------------------------
func placer(x: int, y: int):
	grid_x = x
	grid_y = y
	est_place = true

# -----------------------------------------------
# Retourne true si le joueur peut encore bouger
# -----------------------------------------------
func peut_se_deplacer() -> bool:
	return pm_actuels > 0

# -----------------------------------------------
# Vérifie si la case (x, y) est accessible
# -----------------------------------------------
func peut_se_deplacer_vers(x: int, y: int) -> bool:
	if not peut_se_deplacer():
		return false
	var distance = abs(x - grid_x) + abs(y - grid_y)
	return distance <= pm_actuels

# -----------------------------------------------
# Déplace le joueur et consomme les PM
# -----------------------------------------------
func deplacer(x: int, y: int):
	if peut_se_deplacer_vers(x, y):
		var distance = abs(x - grid_x) + abs(y - grid_y)
		pm_actuels -= distance
		grid_x = x
		grid_y = y

# -----------------------------------------------
# Retourne true si le joueur peut attaquer la cible
# -----------------------------------------------
func peut_attaquer(cible_x: int, cible_y: int) -> bool:
	if a_attaque_ce_tour:
		return false
	if pm_actuels < attaque_cout_pm:
		return false
	var distance = abs(cible_x - grid_x) + abs(cible_y - grid_y)
	return distance <= attaque_portee

# -----------------------------------------------
# Attaque une cible et retourne les dégâts infligés
# -----------------------------------------------
func attaquer(cible: Node) -> int:
	if not peut_attaquer(cible.grid_x, cible.grid_y):
		return 0
	pm_actuels -= attaque_cout_pm
	a_attaque_ce_tour = true
	cible.recevoir_degats(attaque_degats)
	# Gain de gold centralisé — s'applique aussi aux sorts plus tard
	gagner_gold_sur_degats(attaque_degats)
	print("Attaque ! ", attaque_degats, " dégâts — PM restants : ", pm_actuels)
	return attaque_degats

# -----------------------------------------------
# Reçoit des dégâts
# -----------------------------------------------
func recevoir_degats(degats: int):
	hp_actuels -= degats
	hp_actuels = max(0, hp_actuels)
	print("HP restants : ", hp_actuels, " / ", hp_max)

# -----------------------------------------------
# Méthode centralisée pour gagner du Gold
# Appelée par TOUTES les sources de dégâts :
# attaque de base, sorts, effets, etc.
# +1 Gold tous les 10 dégâts infligés
# -----------------------------------------------
func gagner_gold_sur_degats(degats: int):
	var gold_gagne = degats / 10
	if gold_gagne > 0:
		gold += gold_gagne
		print("+", gold_gagne, " Gold ! Total : ", gold)

# -----------------------------------------------
# Réinitialise les PM et l'attaque au début du tour
# -----------------------------------------------
func debut_tour():
	pm_actuels = pm_max
	a_attaque_ce_tour = false

# -----------------------------------------------
# Overridé dans chaque classe fille
# -----------------------------------------------
func utiliser_passif():
	pass
