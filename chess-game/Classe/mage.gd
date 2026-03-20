# =======================================================
# Classe/mage.gd
# -------------------------------------------------------
# Classe Mage — dégâts de zone et contrôle.
#
# Spécialités :
#   - HP faibles (80), grande portée d'attaque (5)
#   - bonus_degats_sorts : +5 sur TOUS les sorts offensifs
#   - Sorts : Boule de Feu, Gel, Météore (différé), Tempête Arcanique
# =======================================================
extends "res://joueur.gd"


# =======================================================
# CONSTANTES — Stats de base
# =======================================================

const MAGE_HP_MAX             : int = 80
const MAGE_ATTAQUE_DEGATS     : int = 10
const MAGE_ATTAQUE_PORTEE     : int = 5
const MAGE_COUT_PM            : int = 1

# Bonus appliqué aux dégâts de TOUS les sorts offensifs
# Cumule avec baton_arcanique (item de classe qui donne +10)
const MAGE_BONUS_DEGATS_SORTS : int = 5


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	hp_max             = MAGE_HP_MAX
	hp_actuels         = MAGE_HP_MAX
	attaque_degats     = MAGE_ATTAQUE_DEGATS
	attaque_portee     = MAGE_ATTAQUE_PORTEE
	attaque_cout_pm    = MAGE_COUT_PM
	bonus_degats_sorts = MAGE_BONUS_DEGATS_SORTS

	const SortsScript = preload("res://Classe/Sort/mage_sorts.gd")
	sorts = SortsScript.creer_sorts()
