# =======================================================
# Classe/fripon.gd
# -------------------------------------------------------
# Classe Fripon — mobilité, combos et or.
#
# Spécialités :
#   - Passif Déplacement : peut réattaquer après chaque déplacement
#     (a_attaque_ce_tour réinitialisé dans input_handler._deplacer())
#   - Passif Gold : +1 Gold tous les 5 dégâts (2x plus que les autres)
#   - Ruée : déverrouillée après 3 attaques de base
#   - Sorts : Ruée, Dérobade (marque + explosion), Lame Empoisonnée, Frénésie
# =======================================================
extends "res://joueur.gd"


# =======================================================
# CONSTANTES — Stats de base
# =======================================================

const FRIPON_HP_MAX         : int = 90
const FRIPON_ATTAQUE_DEGATS : int = 10
const FRIPON_ATTAQUE_PORTEE : int = 1
const FRIPON_COUT_PM        : int = 1


# =======================================================
# CONSTANTES — Passif Gold
# -------------------------------------------------------
# Le Fripon gagne 2x plus de Gold que les autres classes :
# +1 Gold tous les 5 dégâts au lieu de 10 (joueur.GOLD_PAR_DEGATS)
# =======================================================
const FRIPON_GOLD_PAR_DEGATS : int = 5


# =======================================================
# CONSTANTES — Ruée
# =======================================================

# Nombre d'attaques de base pour recharger la Ruée après utilisation
const RUEE_ATTAQUES_REQUISES : int = 3

# Lame Empoisonnée — dégâts bonus immédiats + DoT appliqué sur la cible
const LAME_DEGATS_BONUS : int = 10
const LAME_DOT_DEGATS   : int = 5
const LAME_DOT_DUREE    : int = 3


# =======================================================
# ÉTAT — Déplacement
# =======================================================

# Suivi du déplacement pour les passifs qui en dépendent (Frénésie, etc.)
var s_est_deplace_ce_tour : bool = false


# =======================================================
# ÉTAT — Ruée
# =======================================================

# true au démarrage — se verrouille après utilisation
var ruee_disponible      : bool = true

# Compteur d'attaques depuis la dernière utilisation de la Ruée
# Réinitialisé à 0 à chaque utilisation
var attaques_depuis_ruee : int  = 0


# =======================================================
# ÉTAT — Lame Empoisonnée
# =======================================================

# true = la prochaine attaque de base applique +10 dmg + DoT
# Consommé et remis à false dans fripon.attaquer()
var lame_active : bool = false


# =======================================================
# ÉTAT — Frénésie
# =======================================================

# true = attaques à 0 PM ce tour (consommation ignorée dans attaquer())
# Remis à false au début du tour suivant via debut_tour()
var frenesie_active : bool = false


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	hp_max          = FRIPON_HP_MAX
	hp_actuels      = FRIPON_HP_MAX
	attaque_degats  = FRIPON_ATTAQUE_DEGATS
	attaque_portee  = FRIPON_ATTAQUE_PORTEE
	attaque_cout_pm = FRIPON_COUT_PM

	const SortsScript = preload("res://Classe/Sort/fripon_sorts.gd")
	sorts = SortsScript.creer_sorts()


# =======================================================
# OVERRIDE — peut_attaquer
# -------------------------------------------------------
# Ordre de vérification :
#   1. Distance — toujours vérifiée
#   2. a_attaque_ce_tour — bloqué même en Frénésie
#   3. PM — ignorés en Frénésie uniquement
# =======================================================
func peut_attaquer(cible_x: int, cible_y: int) -> bool:
	var distance : int = abs(cible_x - grid_x) + abs(cible_y - grid_y)
	if distance > attaque_portee:
		return false
	if a_attaque_ce_tour:
		return false
	if frenesie_active:
		return true  # PM non vérifiés — coût géré dans attaquer()
	return pm_actuels >= attaque_cout_pm

# -------------------------------------------------------
# Override — réinitialise la Ruée au début de chaque tour.
# Le Fripon commence toujours son tour avec la Ruée disponible.
# Si la Ruée est utilisée, il faut 3 attaques dans CE tour
# pour pouvoir la relancer avant la fin du tour.
# -------------------------------------------------------
func debut_tour() -> void:
	super.debut_tour()
	ruee_disponible      = true
	attaques_depuis_ruee = 0
	s_est_deplace_ce_tour = false


# =======================================================
# OVERRIDE — attaquer
# -------------------------------------------------------
# Gère la Frénésie (coût 0 PM), la Lame Empoisonnée et
# le compteur de Ruée.
# =======================================================
func attaquer(cible: Node) -> int:
	if not peut_attaquer(cible.grid_x, cible.grid_y):
		return 0

	# Frénésie → coût 0 PM pour toutes les attaques ce tour
	var cout_reel : int = 0 if frenesie_active else attaque_cout_pm
	pm_actuels        -= cout_reel
	a_attaque_ce_tour  = true

	cible.recevoir_degats(attaque_degats)
	gagner_gold_sur_degats(attaque_degats)

	# Lame Empoisonnée — dégâts bonus immédiats + DoT rafraîchi sur la cible
	if lame_active:
		cible.recevoir_degats(LAME_DEGATS_BONUS)
		gagner_gold_sur_degats(LAME_DEGATS_BONUS)
		cible.ajouter_dot("lame_empoisonnee", LAME_DOT_DEGATS, LAME_DOT_DUREE)
		lame_active = false

	# Compteur Ruée — chaque attaque rapproche du déverrouillage
	attaques_depuis_ruee += 1
	if not ruee_disponible and attaques_depuis_ruee >= RUEE_ATTAQUES_REQUISES:
		ruee_disponible = true

	return attaque_degats


# =======================================================
# OVERRIDE — gagner_gold_sur_degats
# -------------------------------------------------------
# +1 Gold tous les FRIPON_GOLD_PAR_DEGATS dégâts (2x la base)
# =======================================================
func gagner_gold_sur_degats(degats: int) -> void:
	var gold_gagne : int = degats / FRIPON_GOLD_PAR_DEGATS
	if gold_gagne > 0:
		gold += gold_gagne
