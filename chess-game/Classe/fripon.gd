# Classes/fripon.gd
# -----------------------------------------------
# FRIPON — Classe agile / économique
# Passif : peut attaquer une 2ème fois après s'être déplacé
#          + 1 Gold tous les 5 dégâts (au lieu de 10)
# Attaque : 10 dégâts, portée 1, coût 1 PM
# -----------------------------------------------
extends "res://joueur.gd"

# --- Passif ---
var s_est_deplace_ce_tour: bool = false
var a_utilise_attaque_bonus: bool = false

# --- Ruée ---
# Pas de CD standard — disponibilité gérée manuellement
# Verrouillée après utilisation, déverrouillée après 3 attaques de base
var ruee_disponible: bool = true
var attaques_depuis_ruee: int = 0

# --- Lame Empoisonnée ---
# Quand active : la prochaine attaque de base applique un DoT (5 dmg/tour, 3 tours)
# Reste active tant qu'il reste des attaques possibles ce tour (synergise avec passif)
var lame_active: bool = false

# --- Frénésie ---
# Quand active : attaques illimitées à 0 PM jusqu'à fin de tour
# Remise à false dans debut_tour()
var frenesie_active: bool = false

func _ready():
	attaque_degats  = 10
	attaque_portee  = 1
	attaque_cout_pm = 1
	const SortsScript = preload("res://Classe/Sort/fripon_sorts.gd")
	sorts = SortsScript.creer_sorts()

# -----------------------------------------------
# peut_attaquer — gère Frénésie + passif
# -----------------------------------------------
func peut_attaquer(cible_x: int, cible_y: int) -> bool:
	var distance = abs(cible_x - grid_x) + abs(cible_y - grid_y)
	if distance > attaque_portee:
		return false
	if frenesie_active:
		return true
	# Frénésie : même règle qu'une attaque normale (1 par tour)
	# mais le coût PM sera 0 dans attaquer()
	if a_attaque_ce_tour:
		return false
	return true  # PM pas vérifiés — coût = 0 géré dans attaquer()
	return pm_actuels >= attaque_cout_pm

	# Frénésie : attaques illimitées, PM non consommés
	if frenesie_active:
		return true

	# Première attaque du tour
	if not a_attaque_ce_tour:
		return pm_actuels >= attaque_cout_pm

	# Passif : 2ème attaque si déplacement effectué et bonus non consommé
	if s_est_deplace_ce_tour and not a_utilise_attaque_bonus:
		return pm_actuels >= attaque_cout_pm

	return false

# -----------------------------------------------
# attaquer — Lame Empoisonnée + compteur Ruée + Frénésie
# -----------------------------------------------
func attaquer(cible: Node) -> int:
	if not peut_attaquer(cible.grid_x, cible.grid_y):
		return 0
	pm_actuels -= 0 if frenesie_active else attaque_cout_pm
	a_attaque_ce_tour = true
	cible.recevoir_degats(attaque_degats)
	gagner_gold_sur_degats(attaque_degats)
	if lame_active:
		cible.recevoir_degats(10)
		gagner_gold_sur_degats(10)
		# ID unique avec un compteur pour permettre le cumul
		var dot_id = "lame_empoisonnee_" + str(Time.get_ticks_msec())
		cible.ajouter_dot(dot_id, 5, 3)
		print("☠️ Lame — +10 dmg + DoT appliqué !")
		if not peut_attaquer(cible.grid_x, cible.grid_y):
			lame_active = false
	attaques_depuis_ruee += 1
	if not ruee_disponible and attaques_depuis_ruee >= 3:
		ruee_disponible = true
		print("🗡️ Ruée déverrouillée !")
	print("Attaque Fripon ! ", attaque_degats, " dmg — PM : ", pm_actuels)
	return attaque_degats

# -----------------------------------------------
# gagner_gold_sur_degats — +1 Gold / 5 dmg
# -----------------------------------------------
func gagner_gold_sur_degats(degats: int):
	var gold_gagne = degats / 5
	if gold_gagne > 0:
		gold += gold_gagne
		print("+", gold_gagne, " Gold (Fripon) ! Total : ", gold)

# -----------------------------------------------
# debut_tour — reset flags de fin de tour
# -----------------------------------------------
func debut_tour():
	super.debut_tour()
	frenesie_active         = false
	s_est_deplace_ce_tour   = false
	# attaques_depuis_ruee → NE PAS reset ici
	# le compteur persiste jusqu'à déverrouillage de la Ruée
