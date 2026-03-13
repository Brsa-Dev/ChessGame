# =======================================================
# Classe/fripon.gd
# -------------------------------------------------------
# Classe Fripon — mobilité et combos.
#
# Spécialités :
#   - Passif : peut réattaquer après chaque déplacement
#   - Gain de Gold x2 sur les dégâts (+1G/5dmg au lieu de /10)
#   - Ruée : se déverrouille après 3 attaques
#   - Lame Empoisonnée + Dérobade + Frénésie
# =======================================================
extends "res://joueur.gd"

# -------------------------------------------------------
# Constantes — stats de base du Fripon
# -------------------------------------------------------
const FRIPON_HP_MAX          : int = 90
const FRIPON_ATTAQUE_DEGATS  : int = 10
const FRIPON_ATTAQUE_PORTEE  : int = 1
const FRIPON_COUT_PM         : int = 1

# -------------------------------------------------------
# Constantes — passif Gold
# Le Fripon gagne +1 Gold tous les 5 dégâts (au lieu de 10)
# -------------------------------------------------------
const FRIPON_GOLD_PAR_DEGATS : int = 5

# -------------------------------------------------------
# Constantes — Ruée
# -------------------------------------------------------
const RUEE_ATTAQUES_REQUISES : int = 3  # Attaques pour déverrouiller la Ruée

# -------------------------------------------------------
# État interne — passif déplacement
# -------------------------------------------------------
var s_est_deplace_ce_tour : bool = false  # Suivi du déplacement ce tour

# -------------------------------------------------------
# État interne — Ruée
# -------------------------------------------------------
var ruee_disponible      : bool = true  # Disponible au démarrage
var attaques_depuis_ruee : int  = 0     # Compteur — reset à l'utilisation de la Ruée

# -------------------------------------------------------
# État interne — Lame Empoisonnée
# -------------------------------------------------------
var lame_active : bool = false  # true = prochaine attaque inflige +10dmg + DoT

# -------------------------------------------------------
# État interne — Frénésie
# -------------------------------------------------------
var frenesie_active : bool = false  # true = attaques à 0 PM ce tour


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
# Ordre de vérification IMPORTANT :
#   1. Distance — toujours vérifiée
#   2. a_attaque_ce_tour — même en Frénésie (pas d'attaques illimitées)
#   3. PM — ignorés en Frénésie (coût = 0)
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


# =======================================================
# OVERRIDE — attaquer
# -------------------------------------------------------
# Gère la Frénésie (0 PM), la Lame Empoisonnée et la Ruée
# =======================================================
func attaquer(cible: Node) -> int:
	if not peut_attaquer(cible.grid_x, cible.grid_y):
		return 0

	# Frénésie → coût 0 PM, sinon coût normal
	var cout_reel : int = 0 if frenesie_active else attaque_cout_pm
	pm_actuels        -= cout_reel
	a_attaque_ce_tour  = true

	cible.recevoir_degats(attaque_degats)
	gagner_gold_sur_degats(attaque_degats)

	# Synergie Lame Empoisonnée — +10 dmg + DoT rafraîchi
	if lame_active:
		cible.recevoir_degats(10)
		gagner_gold_sur_degats(10)
		cible.ajouter_dot("lame_empoisonnee", 5, 3)
		lame_active = false
		print("☠️ Lame — +10 dmg + DoT rafraîchi !")

	# Compteur Ruée — incrémenté à chaque attaque de base
	attaques_depuis_ruee += 1
	if not ruee_disponible and attaques_depuis_ruee >= RUEE_ATTAQUES_REQUISES:
		ruee_disponible = true
		print("🗡️ Ruée déverrouillée !")

	print("⚔️ Fripon attaque ! %d dmg — PM : %d" % [attaque_degats, pm_actuels])
	return attaque_degats


# =======================================================
# OVERRIDE — gagner_gold_sur_degats
# Le Fripon gagne 2x plus de Gold (+1G tous les 5 dmg)
# =======================================================
func gagner_gold_sur_degats(degats: int) -> void:
	var gold_gagne : int = degats / FRIPON_GOLD_PAR_DEGATS
	if gold_gagne > 0:
		gold += gold_gagne
		print("💰 +%d Gold (Fripon) ! Total : %d" % [gold_gagne, gold])


func utiliser_passif() -> void:
	pass
