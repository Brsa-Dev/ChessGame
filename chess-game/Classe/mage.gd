# Classes/mage.gd
# -----------------------------------------------
# MAGE — Classe à distance / sorts
# Passif : +5 dégâts sur tous les sorts
# Attaque : 10 dégâts, portée 5, coût 1 PM
# ⚠️ 80 HP seulement
# -----------------------------------------------
extends "res://joueur.gd"

func _ready():
	# --- Stats spécifiques au Mage ---
	hp_max = 80            # Plus fragile
	hp_actuels = 80
	attaque_degats = 10
	attaque_portee = 5     # Très longue portée
	attaque_cout_pm = 1

	# Le passif est stocké ici — utilisé dans les sorts
	# (branché dans sort.gd à l'Étape 7b)
	bonus_degats_sorts = 5
	
	const SortsScript = preload("res://Classe/Sort/mage_sorts.gd")
	sorts = SortsScript.creer_sorts()

func utiliser_passif():
	# Le passif s'applique automatiquement dans chaque sort
	# via la variable bonus_degats_sorts
	pass
