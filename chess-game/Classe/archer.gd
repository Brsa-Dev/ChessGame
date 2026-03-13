# =======================================================
# Classe/archer.gd
# -------------------------------------------------------
# Classe Archer — mobilité et dégâts à distance.
#
# Spécialités :
#   - Portée d'attaque 3 (4 en forêt)
#   - Passif Forêt : +1 portée d'attaque sur case Forêt
#   - Sorts : Flèche Rebondissante, Piège, Tir Ciblé, Pluie
# =======================================================
extends "res://joueur.gd"

# -------------------------------------------------------
# Constantes — stats de base de l'Archer
# -------------------------------------------------------
const ARCHER_HP_MAX            : int = 90
const ARCHER_ATTAQUE_DEGATS    : int = 15
const ARCHER_ATTAQUE_PORTEE    : int = 3
const ARCHER_COUT_PM           : int = 1

# -------------------------------------------------------
# Constantes — passif Forêt
# -------------------------------------------------------
const ARCHER_PORTEE_FORET_BONUS : int = 1  # +1 portée en forêt

# -------------------------------------------------------
# État interne — passif Forêt
# -------------------------------------------------------
var est_en_foret : bool = false


func _ready() -> void:
	hp_max          = ARCHER_HP_MAX
	hp_actuels      = ARCHER_HP_MAX
	attaque_degats  = ARCHER_ATTAQUE_DEGATS
	attaque_portee  = ARCHER_ATTAQUE_PORTEE
	attaque_cout_pm = ARCHER_COUT_PM

	const SortsScript = preload("res://Classe/Sort/archer_sorts.gd")
	sorts = SortsScript.creer_sorts()


# =======================================================
# PASSIF FORÊT
# -------------------------------------------------------
# Bonus de portée d'attaque quand l'Archer est en forêt.
# Appelé par effects_handler lors du changement de case.
# =======================================================

# -------------------------------------------------------
# Active le bonus — appelé en entrant sur une case Forêt
# -------------------------------------------------------
func entrer_foret() -> void:
	if not est_en_foret:
		est_en_foret    = true
		attaque_portee += ARCHER_PORTEE_FORET_BONUS
		print("🌲 %s — Passif Forêt : portée %d→%d" % [
			name,
			attaque_portee - ARCHER_PORTEE_FORET_BONUS,
			attaque_portee
		])


# -------------------------------------------------------
# Désactive le bonus — appelé en quittant la case Forêt
# -------------------------------------------------------
func quitter_foret() -> void:
	if est_en_foret:
		est_en_foret    = false
		attaque_portee -= ARCHER_PORTEE_FORET_BONUS
		attaque_portee  = max(1, attaque_portee)  # Sécurité — portée min 1
		print("🍂 %s — Passif Forêt désactivé" % name)


func utiliser_passif() -> void:
	pass
