# Classes/guerrier.gd
extends "res://joueur.gd"

# True si la Rage Berserker est active
var rage_active: bool = false
# Compteur de tours restants pour la Rage
var tours_rage_restants: int = 0

func _ready():
	hp_max = 120
	hp_actuels = 120
	attaque_degats = 20
	attaque_portee = 1
	attaque_cout_pm = 1
	
	# Charge les sorts depuis guerrier_sorts.gd
	const SortsScript = preload("res://Classe/Sort/guerrier_sorts.gd")
	sorts = SortsScript.creer_sorts()

# -----------------------------------------------
# Override debut_tour — gère la durée de la Rage
# -----------------------------------------------
func debut_tour():
	super.debut_tour()
	
	if rage_active:
		tours_rage_restants -= 1
		if tours_rage_restants <= 0:
			# La Rage se termine — on retire les bonus
			_desactiver_rage()

# -----------------------------------------------
# Active la Rage Berserker
# -----------------------------------------------
func activer_rage():
	rage_active = true
	tours_rage_restants = 2
	attaque_degats *= 2   # x2 attaque
	pm_max += 2           # +2 PM
	pm_actuels += 2
	print("⚔️ Rage Berserker ! x2 attaque, +2 PM — Durée : 2 tours")

# -----------------------------------------------
# Désactive la Rage Berserker (fin de durée)
# -----------------------------------------------
func _desactiver_rage():
	rage_active = false
	attaque_degats /= 2   # Retire le x2
	pm_max -= 2           # Retire les +2 PM
	pm_actuels = min(pm_actuels, pm_max)
	print("⚔️ Rage Berserker terminée")

# -----------------------------------------------
# Override recevoir_degats — immunité pendant la Rage
# -----------------------------------------------
func recevoir_degats(degats: int):
	if rage_active:
		print("⚔️ Immunisé ! (Rage Berserker active)")
		return
	super.recevoir_degats(degats)

func utiliser_passif():
	pass
