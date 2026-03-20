# =======================================================
# Classe/guerrier.gd
# -------------------------------------------------------
# Classe Guerrier — tank corps-à-corps.
#
# Spécialités :
#   - HP élevés (120), dégâts élevés (20), portée 1
#   - Rage Berserker : x2 attaque + immunité dégâts pendant 2 tours
#   - Override debut_tour() → décrémente la Rage
# =======================================================
extends "res://joueur.gd"


# =======================================================
# CONSTANTES — Stats de base
# =======================================================

const GUERRIER_HP_MAX         : int = 120
const GUERRIER_ATTAQUE_DEGATS : int = 20
const GUERRIER_ATTAQUE_PORTEE : int = 1
const GUERRIER_COUT_PM        : int = 1


# =======================================================
# CONSTANTES — Rage Berserker
# =======================================================

const RAGE_MULTIPLICATEUR_ATTAQUE : int = 2  # x2 dégâts pendant la Rage
const RAGE_BONUS_PM               : int = 2  # PM supplémentaires au déclenchement
const RAGE_DUREE_TOURS            : int = 2  # Tours de durée de la Rage


# =======================================================
# ÉTAT — Rage Berserker
# =======================================================

var rage_active         : bool = false  # true = immunité + x2 attaque
var tours_rage_restants : int  = 0      # Décrémenté dans debut_tour()


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	hp_max          = GUERRIER_HP_MAX
	hp_actuels      = GUERRIER_HP_MAX
	attaque_degats  = GUERRIER_ATTAQUE_DEGATS
	attaque_portee  = GUERRIER_ATTAQUE_PORTEE
	attaque_cout_pm = GUERRIER_COUT_PM

	const SortsScript = preload("res://Classe/Sort/guerrier_sorts.gd")
	sorts = SortsScript.creer_sorts()


# =======================================================
# OVERRIDE — Début de tour
# -------------------------------------------------------
# Décrémente la Rage si active et désactive quand elle expire.
# super.debut_tour() gère PM, DoT, immobilisation, et CDs.
# =======================================================
func debut_tour() -> void:
	super.debut_tour()

	if not rage_active:
		return

	tours_rage_restants -= 1
	if tours_rage_restants <= 0:
		_desactiver_rage()

# =======================================================
# RAGE BERSERKER
# =======================================================

# -------------------------------------------------------
# Active la Rage — appelée par sort_handler quand le sort est utilisé.
# x2 attaque, +2 PM, immunité aux dégâts pendant RAGE_DUREE_TOURS.
# -------------------------------------------------------
func activer_rage() -> void:
	rage_active         = true
	tours_rage_restants = RAGE_DUREE_TOURS
	attaque_degats     *= RAGE_MULTIPLICATEUR_ATTAQUE
	pm_max             += RAGE_BONUS_PM
	pm_actuels         += RAGE_BONUS_PM


# -------------------------------------------------------
# Désactive la Rage — retire tous les bonus
# -------------------------------------------------------
func _desactiver_rage() -> void:
	rage_active     = false
	attaque_degats /= RAGE_MULTIPLICATEUR_ATTAQUE
	pm_max         -= RAGE_BONUS_PM
	# pm_actuels peut avoir été consommé pendant la Rage — on plafonne
	pm_actuels      = min(pm_actuels, pm_max)
