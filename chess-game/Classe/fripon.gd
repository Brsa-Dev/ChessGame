# Classes/fripon.gd
extends "res://joueur.gd"

# --- Passif ---
var s_est_deplace_ce_tour: bool = false

# --- Ruée ---
var ruee_disponible: bool = true
var attaques_depuis_ruee: int = 0  # Persiste entre les tours — reset uniquement à l'utilisation

# --- Lame Empoisonnée ---
var lame_active: bool = false

# --- Frénésie ---
var frenesie_active: bool = false

func _ready():
	attaque_degats  = 10
	attaque_portee  = 1
	attaque_cout_pm = 1
	const SortsScript = preload("res://Classe/Sort/fripon_sorts.gd")
	sorts = SortsScript.creer_sorts()

# -----------------------------------------------
# peut_attaquer
# ORDRE IMPORTANT :
#   1. Distance
#   2. a_attaque_ce_tour — toujours vérifié, même en Frénésie
#   3. PM — sautés en Frénésie (coût = 0)
# -----------------------------------------------
func peut_attaquer(cible_x: int, cible_y: int) -> bool:
	var distance = abs(cible_x - grid_x) + abs(cible_y - grid_y)
	if distance > attaque_portee:
		return false
	# Frénésie ne donne PAS d'attaques illimitées — elle donne 0 PM
	# Le passif (déplacement) reste le seul moyen d'enchaîner les attaques
	if a_attaque_ce_tour:
		return false
	if frenesie_active:
		return true  # PM non vérifiés — coût = 0 géré dans attaquer()
	return pm_actuels >= attaque_cout_pm

# -----------------------------------------------
# attaquer — Lame + Ruée + Frénésie
# -----------------------------------------------
func attaquer(cible: Node) -> int:
	if not peut_attaquer(cible.grid_x, cible.grid_y):
		return 0

	# Frénésie : 0 PM, sinon coût normal
	pm_actuels -= 0 if frenesie_active else attaque_cout_pm
	a_attaque_ce_tour = true

	cible.recevoir_degats(attaque_degats)
	gagner_gold_sur_degats(attaque_degats)

	# Synergie Lame Empoisonnée
	if lame_active:
		cible.recevoir_degats(10)
		gagner_gold_sur_degats(10)
		# ID fixe — écrase le DoT existant si déjà présent = refresh
		cible.ajouter_dot("lame_empoisonnee", 5, 3)
		lame_active = false
		print("☠️ Lame — +10 dmg + DoT rafraîchi !")

	# Compteur Ruée — incrémenté à chaque attaque de base
	attaques_depuis_ruee += 1
	if not ruee_disponible and attaques_depuis_ruee >= 3:
		ruee_disponible = true
		print("🗡️ Ruée déverrouillée !")

	print("Attaque Fripon ! ", attaque_degats, " dmg — PM : ", pm_actuels)
	return attaque_degats

# -----------------------------------------------
# gagner_gold_sur_degats — +1 Gold / 5 dmg (override)
# -----------------------------------------------
func gagner_gold_sur_degats(degats: int):
	var gold_gagne = degats / 5
	if gold_gagne > 0:
		gold += gold_gagne
		print("+", gold_gagne, " Gold (Fripon) ! Total : ", gold)

# -----------------------------------------------
# debut_tour — reset uniquement ce qui doit l'être
# -----------------------------------------------
func debut_tour():
	super.debut_tour()
	frenesie_active       = false
	s_est_deplace_ce_tour = false
	# Ruée : mécanique per-tour — reset au début de chaque tour
	# → Ruée toujours disponible en début de tour
	ruee_disponible      = true
	attaques_depuis_ruee = 0
