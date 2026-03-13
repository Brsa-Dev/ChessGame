# =======================================================
# Classe/guerrier.gd
# -------------------------------------------------------
# Classe Guerrier — tank corpo-à-corpo.
#
# Spécialités :
#   - HP élevés (120), dégâts élevés (20)
#   - Rage Berserker : x2 attaque + immunité dégâts
#   - Passif : immunité aux dégâts pendant la Rage
# =======================================================
extends "res://joueur.gd"

# -------------------------------------------------------
# Constantes — stats de base du Guerrier
# -------------------------------------------------------
const GUERRIER_HP_MAX        : int = 120
const GUERRIER_ATTAQUE_DEGATS: int = 20
const GUERRIER_ATTAQUE_PORTEE: int = 1
const GUERRIER_COUT_PM       : int = 1

# -------------------------------------------------------
# Constantes — Rage Berserker
# -------------------------------------------------------
const RAGE_MULTIPLICATEUR_ATTAQUE : int = 2  # x2 dégâts d'attaque
const RAGE_BONUS_PM               : int = 2  # +2 PM pendant la Rage
const RAGE_DUREE_TOURS            : int = 2  # Tours de durée de la Rage

# -------------------------------------------------------
# État interne — Rage Berserker
# -------------------------------------------------------
var rage_active          : bool = false
var tours_rage_restants  : int  = 0


func _ready() -> void:
	hp_max         = GUERRIER_HP_MAX
	hp_actuels     = GUERRIER_HP_MAX
	attaque_degats = GUERRIER_ATTAQUE_DEGATS
	attaque_portee = GUERRIER_ATTAQUE_PORTEE
	attaque_cout_pm = GUERRIER_COUT_PM

	const SortsScript = preload("res://Classe/Sort/guerrier_sorts.gd")
	sorts = SortsScript.creer_sorts()


# =======================================================
# OVERRIDE — Début de tour
# Décrémente la durée de la Rage si active
# =======================================================
func debut_tour() -> void:
	super.debut_tour()

	if rage_active:
		tours_rage_restants -= 1
		if tours_rage_restants <= 0:
			_desactiver_rage()


# =======================================================
# OVERRIDE — Réception de dégâts
# Immunité totale pendant la Rage Berserker
# =======================================================
func recevoir_degats(degats: int) -> void:
	if rage_active:
		print("⚔️ %s — Immunisé ! (Rage active)" % name)
		return
	super.recevoir_degats(degats)


# =======================================================
# RAGE BERSERKER
# =======================================================

# -------------------------------------------------------
# Active la Rage — x2 attaque, +2 PM, immunité dégâts
# Appelée par sort_handler quand le sort est utilisé
# -------------------------------------------------------
func activer_rage() -> void:
	rage_active         = true
	tours_rage_restants = RAGE_DUREE_TOURS
	attaque_degats     *= RAGE_MULTIPLICATEUR_ATTAQUE
	pm_max             += RAGE_BONUS_PM
	pm_actuels         += RAGE_BONUS_PM
	print("⚔️ Rage Berserker ! x%d attaque, +%d PM — %d tours" % [
		RAGE_MULTIPLICATEUR_ATTAQUE, RAGE_BONUS_PM, RAGE_DUREE_TOURS
	])


# -------------------------------------------------------
# Désactive la Rage — retire les bonus
# -------------------------------------------------------
func _desactiver_rage() -> void:
	rage_active     = false
	attaque_degats /= RAGE_MULTIPLICATEUR_ATTAQUE
	pm_max         -= RAGE_BONUS_PM
	pm_actuels      = min(pm_actuels, pm_max)
	print("⚔️ Rage Berserker terminée")


func utiliser_passif() -> void:
	pass
