# Classes/archer.gd
# -----------------------------------------------
# ARCHER — Classe polyvalente / terrain
# Passif : En forêt → coût 1 PM au lieu de 2
#          + 1 Range et +10 attaque de base
# Attaque : 20 dégâts, portée 3, coût 2 PM
# -----------------------------------------------
extends "res://joueur.gd"

# True si le joueur est actuellement en forêt
var est_en_foret: bool = false

func _ready():
	# --- Stats spécifiques à l'Archer ---
	attaque_degats = 20
	attaque_portee = 3     # Portée moyenne
	attaque_cout_pm = 2    # Plus coûteux que les autres

func utiliser_passif():
	# Appelée par main.gd quand l'Archer arrive/quitte une forêt
	# Les bonus sont appliqués/retirés directement à ce moment
	pass

# -----------------------------------------------
# Applique les bonus de forêt (appelée par main.gd)
# -----------------------------------------------
func entrer_foret():
	if not est_en_foret:
		est_en_foret = true
		attaque_portee += 1   # +1 Range
		attaque_degats += 10  # +10 attaque
		print("🌲 Passif Archer actif ! +1 Range, +10 attaque")

# -----------------------------------------------
# Retire les bonus de forêt (appelée par main.gd)
# -----------------------------------------------
func quitter_foret():
	if est_en_foret:
		est_en_foret = false
		attaque_portee -= 1
		attaque_degats -= 10
		print("🌲 Passif Archer désactivé")
