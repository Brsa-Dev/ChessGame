# =======================================================
# Classe/archer.gd
# -------------------------------------------------------
# Classe Archer — mobilité et dégâts à distance.
#
# Spécialités :
#   - Portée d'attaque 3 (4 en forêt grâce au passif)
#   - Passif Forêt : +1 portée d'attaque sur case Forêt
#     → entrer_foret() / quitter_foret() appelées par effects_handler
#   - La Flèche Rebondissante lit attaque_portee (pas sort.portee)
#     pour bénéficier du bonus Forêt automatiquement
# =======================================================
extends "res://joueur.gd"


# =======================================================
# CONSTANTES — Stats de base
# =======================================================

const ARCHER_HP_MAX            : int = 90
const ARCHER_ATTAQUE_DEGATS    : int = 15
const ARCHER_ATTAQUE_PORTEE    : int = 3
const ARCHER_COUT_PM           : int = 1


# =======================================================
# CONSTANTES — Passif Forêt
# =======================================================

# Bonus de portée d'attaque quand l'Archer est sur une case Forêt
const ARCHER_PORTEE_FORET_BONUS : int = 1
const PORTEE_MINIMUM            : int = 1  # Portée d'attaque minimale (sécurité)


# =======================================================
# ÉTAT — Passif Forêt
# =======================================================

# Suivi interne pour éviter d'appliquer/retirer le bonus deux fois
var est_en_foret : bool = false


# =======================================================
# INITIALISATION
# =======================================================
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
# Appelées par effects_handler.appliquer_effet_case()
# à chaque fois que l'Archer entre ou quitte une case Forêt.
# =======================================================

# -------------------------------------------------------
# Active le bonus de portée — appelée en entrant sur une case Forêt
# -------------------------------------------------------
func entrer_foret() -> void:
	if est_en_foret:
		return  # Déjà actif — pas de double application
	est_en_foret    = true
	attaque_portee += ARCHER_PORTEE_FORET_BONUS


# -------------------------------------------------------
# Retire le bonus de portée — appelée en quittant une case Forêt
# -------------------------------------------------------
func quitter_foret() -> void:
	if not est_en_foret:
		return  # Pas actif — rien à retirer
	est_en_foret    = false
	attaque_portee -= ARCHER_PORTEE_FORET_BONUS
	attaque_portee  = max(PORTEE_MINIMUM, attaque_portee)
