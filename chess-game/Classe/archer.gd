# Classes/archer.gd
# -----------------------------------------------
# ARCHER — Classe polyvalente / terrain
# Passif : En forêt → coût 1 PM au lieu de 2
#          + 1 Range et +10 attaque de base
# Attaque : 20 dégâts, portée 3, coût 2 PM
# -----------------------------------------------
extends "res://joueur.gd"

var est_en_foret: bool = false

func _ready():
	attaque_degats = 20
	attaque_portee = 3
	attaque_cout_pm = 2
	
	# Charge les sorts depuis archer_sorts.gd
	const SortsScript = preload("res://Classe/Sort/archer_sorts.gd")
	sorts = SortsScript.creer_sorts()

func utiliser_passif():
	pass

func entrer_foret():
	if not est_en_foret:
		est_en_foret = true
		attaque_portee += 1
		attaque_degats += 10
		print("🌲 Passif Archer actif ! +1 Range, +10 attaque")

func quitter_foret():
	if est_en_foret:
		est_en_foret = false
		attaque_portee -= 1
		attaque_degats -= 10
		print("🌲 Passif Archer désactivé")
