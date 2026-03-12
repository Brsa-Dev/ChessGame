# Classes/fripon.gd
# -----------------------------------------------
# FRIPON — Classe agile / économique
# Passif : peut attaquer une 2ème fois après s'être déplacé
#          + 1 Gold tous les 5 dégâts (au lieu de 10)
# Attaque : 10 dégâts, portée 1, coût 1 PM
# -----------------------------------------------
extends "res://joueur.gd"

# True si le joueur s'est déplacé ce tour
# → autorise une 2ème attaque
var s_est_deplace_ce_tour: bool = false

# True si le Fripon a utilisé sa 2ème attaque
var a_utilise_attaque_bonus: bool = false

func _ready():
	# --- Stats spécifiques au Fripon ---
	attaque_degats = 10
	attaque_portee = 1
	attaque_cout_pm = 1

# -----------------------------------------------
# Override de peut_attaquer :
# Le Fripon peut attaquer une 2ème fois s'il s'est déplacé
# -----------------------------------------------
func peut_attaquer(cible_x: int, cible_y: int) -> bool:
	# Cas normal — première attaque
	if not a_attaque_ce_tour:
		if pm_actuels < attaque_cout_pm:
			return false
		var distance = abs(cible_x - grid_x) + abs(cible_y - grid_y)
		return distance <= attaque_portee

	# Cas passif — 2ème attaque si déplacement effectué et bonus pas encore utilisé
	if s_est_deplace_ce_tour and not a_utilise_attaque_bonus:
		if pm_actuels < attaque_cout_pm:
			return false
		var distance = abs(cible_x - grid_x) + abs(cible_y - grid_y)
		return distance <= attaque_portee

	return false

# -----------------------------------------------
# Override de attaquer : marque l'attaque bonus si utilisée
# -----------------------------------------------
func attaquer(cible: Node) -> int:
	if not peut_attaquer(cible.grid_x, cible.grid_y):
		return 0

	pm_actuels -= attaque_cout_pm

	# Si c'est la 2ème attaque, on marque le bonus utilisé
	if a_attaque_ce_tour:
		a_utilise_attaque_bonus = true
	else:
		a_attaque_ce_tour = true

	cible.recevoir_degats(attaque_degats)
	gagner_gold_sur_degats(attaque_degats)
	print("Attaque Fripon ! ", attaque_degats, " dégâts — PM restants : ", pm_actuels)
	return attaque_degats

# -----------------------------------------------
# Override de gagner_gold_sur_degats :
# +1 Gold tous les 5 dégâts au lieu de 10
# -----------------------------------------------
func gagner_gold_sur_degats(degats: int):
	var gold_gagne = degats / 5  # Ratio x2 par rapport à la base
	if gold_gagne > 0:
		gold += gold_gagne
		print("+", gold_gagne, " Gold (Fripon) ! Total : ", gold)

# -----------------------------------------------
# Override de debut_tour : remet les flags à zéro
# -----------------------------------------------
func debut_tour():
	super.debut_tour()  # Appelle la version de joueur.gd
	s_est_deplace_ce_tour = false
	a_utilise_attaque_bonus = false
