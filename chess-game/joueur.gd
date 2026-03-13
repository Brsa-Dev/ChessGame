# =======================================================
# joueur.gd
# -------------------------------------------------------
# Classe de BASE pour tous les joueurs.
# Chaque classe (Guerrier, Mage, Archer, Fripon) hérite
# de ce fichier et surcharge les valeurs par défaut.
#
# Contient :
#   - Stats (HP, PM, Gold, position)
#   - Attaque de base
#   - Système de DoT (dégâts sur la durée)
#   - Gestion du début de tour
#   - Variables des items de classe
# =======================================================
extends Node

# -------------------------------------------------------
# Constantes — valeurs par défaut (surchargées par les classes)
# -------------------------------------------------------
const HP_MAX_DEFAUT          : int   = 100
const PM_MAX_DEFAUT          : int   = 5
const ATTAQUE_DEGATS_DEFAUT  : int   = 10
const ATTAQUE_PORTEE_DEFAUT  : int   = 1
const ATTAQUE_COUT_PM_DEFAUT : int   = 1

# -------------------------------------------------------
# Constante — gain de Gold par dégâts infligés
# +1 Gold tous les 10 dégâts
# -------------------------------------------------------
const GOLD_PAR_DEGATS : int = 10

# -------------------------------------------------------
# Signal émis quand le joueur atteint 0 HP
# Écouté par main.gd pour gérer la mort
# -------------------------------------------------------
signal mort


# =======================================================
# ÉTAT — Position sur le plateau
# =======================================================
var grid_x    : int  = 0      # Colonne sur le plateau
var grid_y    : int  = 0      # Ligne sur le plateau
var est_place : bool = false  # False avant le placement initial
var est_mort  : bool = false  # True quand HP tombent à 0


# =======================================================
# STATS — Points de vie
# =======================================================
var hp_max     : int = HP_MAX_DEFAUT
var hp_actuels : int = HP_MAX_DEFAUT


# =======================================================
# STATS — Points de mouvement
# =======================================================
var pm_max     : int = PM_MAX_DEFAUT
var pm_actuels : int = PM_MAX_DEFAUT

# Malus de PM à appliquer au prochain debut_tour()
# Déclenché par la Tempête Électrique via event_manager
var pm_malus_prochain_tour : int = 0


# =======================================================
# STATS — Gold et progression
# =======================================================
var gold   : int = 0
var niveau : int = 1


# =======================================================
# ATTAQUE DE BASE
# Valeurs génériques — surchargées par chaque classe fille
# =======================================================
var attaque_degats    : int  = ATTAQUE_DEGATS_DEFAUT
var attaque_portee    : int  = ATTAQUE_PORTEE_DEFAUT
var attaque_cout_pm   : int  = ATTAQUE_COUT_PM_DEFAUT
var a_attaque_ce_tour : bool = false  # Réinitialisé dans debut_tour()


# =======================================================
# RÉSISTANCES AUX DÉGÂTS
# Cumulables — résistance finale = resistance_degats + resistance_case
# =======================================================
var resistance_degats : float = 0.0  # Permanente (Amulette de Résistance)
var resistance_case   : float = 0.0  # Temporaire (case Forêt)


# =======================================================
# BONUS DE SORTS
# =======================================================
var bonus_degats_sorts  : int = 0  # Bonus flat sur les dégâts des sorts (Mage)
var bonus_range_sorts   : int = 0  # Bonus de portée des sorts (case Tour)


# =======================================================
# INVENTAIRE & ACHATS
# =======================================================
var inventaire       : Array      = []  # Items actuellement possédés
var achats_par_item  : Dictionary = {}  # { "elixir_gold": 1 } — suivi des limites


# =======================================================
# SORTS
# -------------------------------------------------------
# Initialisé par chaque classe fille dans _ready()
# via son fichier xxx_sorts.gd
# =======================================================
var sorts           : Array = []
var sort_selectionne: int   = -1  # Index du sort actif (-1 = aucun)


# =======================================================
# EFFETS DE STATUT
# =======================================================

# Nombre de tours restants d'immobilisation (Gel, Piège)
var tours_immobilise : int = 0

# Cible marquée par la Dérobade du Fripon
# null = aucune marque active
var marque_cible          : Node = null
var marque_tours_restants : int  = 0  # Expiration après 3 tours sans explosion


# =======================================================
# DOTS — Dégâts sur la durée
# -------------------------------------------------------
# Format : { "source_id": { "degats": int, "tours_restants": int } }
# source_id unique → permet le cumul et le refresh
# =======================================================
var dots_actifs : Dictionary = {}


# =======================================================
# VARIABLES ITEMS DE CLASSE
# -------------------------------------------------------
# Initialisées à false/0 — activées par shop_manager
# quand l'item correspondant est acheté
# =======================================================

# ARCHER — Flèches Empoisonnées
# true = la prochaine attaque de base applique un DoT
var fleches_empoisonnees_actif : bool = false

# ARCHER — Piège Amélioré
# true = les pièges posés immobilisent 2 tours au lieu de 1
var piege_ameliore_actif : bool = false

# ARCHER — Cape de Forêt
# Nombre de charges restantes (2 max par item)
var cape_foret_charges : int = 0

# FRIPON — Ceinture de Pickpocket
# true = chaque attaque de base vole 1 Gold à l'ennemi
var pickpocket_actif : bool = false

# FRIPON — Potion de Frénésie
# Réduction du coût Gold du sort Frénésie
var reduction_cout_frenesie : int = 0

# MAGE — Cristal de Mana
# Réduction permanente du coût Gold de Tempête Arcanique
var reduction_cout_tempete : int = 0


# =======================================================
# PLACEMENT
# =======================================================

# -------------------------------------------------------
# Place le joueur sur la case (x, y) du plateau
# Appelée par input_handler lors du placement initial
# -------------------------------------------------------
func placer(x: int, y: int) -> void:
	grid_x    = x
	grid_y    = y
	est_place = true


# =======================================================
# DÉPLACEMENT
# =======================================================

# -------------------------------------------------------
# Retourne true si le joueur peut encore se déplacer ce tour
# -------------------------------------------------------
func peut_se_deplacer() -> bool:
	return pm_actuels > 0 and tours_immobilise <= 0


# -------------------------------------------------------
# Retourne true si la case (x, y) est accessible ce tour
# Vérifie PM restants et distance de Manhattan
# -------------------------------------------------------
func peut_se_deplacer_vers(x: int, y: int) -> bool:
	if not peut_se_deplacer():
		return false
	var distance : int = abs(x - grid_x) + abs(y - grid_y)
	return distance <= pm_actuels


# -------------------------------------------------------
# Déplace le joueur vers (x, y) et consomme les PM
# cout_pm : coût explicite (ex: Forêt = 2), -1 = distance normale
# -------------------------------------------------------
func deplacer(x: int, y: int, cout_pm: int = -1) -> void:
	if not peut_se_deplacer_vers(x, y):
		return
	var cout_reel : int = cout_pm if cout_pm != -1 else abs(x - grid_x) + abs(y - grid_y)
	pm_actuels -= cout_reel
	grid_x      = x
	grid_y      = y


# =======================================================
# ATTAQUE DE BASE
# =======================================================

# -------------------------------------------------------
# Retourne true si ce joueur peut attaquer la case (x, y)
# -------------------------------------------------------
func peut_attaquer(cible_x: int, cible_y: int) -> bool:
	if a_attaque_ce_tour:
		return false
	if pm_actuels < attaque_cout_pm:
		return false
	var distance : int = abs(cible_x - grid_x) + abs(cible_y - grid_y)
	return distance <= attaque_portee


# -------------------------------------------------------
# Attaque une cible et retourne les dégâts infligés
# -------------------------------------------------------
func attaquer(cible: Node) -> int:
	if not peut_attaquer(cible.grid_x, cible.grid_y):
		return 0
	pm_actuels        -= attaque_cout_pm
	a_attaque_ce_tour  = true
	cible.recevoir_degats(attaque_degats)
	gagner_gold_sur_degats(attaque_degats)
	print("⚔️ Attaque ! %d dmg — PM restants : %d" % [attaque_degats, pm_actuels])
	return attaque_degats


# -------------------------------------------------------
# Reçoit des dégâts en tenant compte des résistances
# Résistance totale = resistance_degats + resistance_case
# -------------------------------------------------------
func recevoir_degats(degats: int) -> void:
	var resistance_totale : float = resistance_degats + resistance_case
	var degats_reduits    : int   = int(degats * (1.0 - resistance_totale))
	hp_actuels = max(0, hp_actuels - degats_reduits)
	print("💢 %s — %d dmg reçus (%d HP restants)" % [name, degats_reduits, hp_actuels])
	if hp_actuels <= 0:
		est_mort = true
		print("💀 %s éliminé !" % name)
		emit_signal("mort")


# =======================================================
# GOLD
# =======================================================

# -------------------------------------------------------
# Gagne du Gold proportionnellement aux dégâts infligés
# +1 Gold tous les GOLD_PAR_DEGATS dégâts
# Appelé après TOUTE source de dégâts (attaque, sorts, DoT)
# -------------------------------------------------------
func gagner_gold_sur_degats(degats: int) -> void:
	var gold_gagne : int = degats / GOLD_PAR_DEGATS
	if gold_gagne > 0:
		gold += gold_gagne
		print("💰 +%d Gold ! Total : %d" % [gold_gagne, gold])


# =======================================================
# DOTS — Dégâts sur la durée
# =======================================================

# -------------------------------------------------------
# Ajoute ou rafraîchit un DoT sur ce joueur
# Si source_id existe déjà → le DoT est rafraîchi (pas cumulé)
# -------------------------------------------------------
func ajouter_dot(source_id: String, degats_par_tour: int, duree: int) -> void:
	dots_actifs[source_id] = {
		"degats"          : degats_par_tour,
		"tours_restants"  : duree
	}
	print("☠️ DoT [%s] : %d dmg/tour pendant %d tours" % [source_id, degats_par_tour, duree])


# -------------------------------------------------------
# Applique tous les DoT actifs et décrémente leur durée
# Appelée dans debut_tour() → les DoT s'appliquent
# au début du tour du joueur affecté
# -------------------------------------------------------
func appliquer_dots() -> void:
	var rage : Variant = get("rage_active")
	# Si le joueur est en Rage Berserker, les DoT sont ignorés ce tour
	if rage != null and rage == true:
		print("⚔️ %s — Rage active, DoT ignorés ce tour" % name)
		return

	var dots_expires : Array = []
	for source_id in dots_actifs:
		var dot : Dictionary = dots_actifs[source_id]
		recevoir_degats(dot["degats"])
		dot["tours_restants"] -= 1
		if dot["tours_restants"] <= 0:
			dots_expires.append(source_id)
			print("☠️ DoT [%s] expiré" % source_id)
		else:
			print("☠️ DoT [%s] — %d tour(s) restant(s)" % [source_id, dot["tours_restants"]])
	for source_id in dots_expires:
		dots_actifs.erase(source_id)


# =======================================================
# DÉBUT DE TOUR
# -------------------------------------------------------
# Réinitialise PM, attaque, cooldowns, immobilisation
# et applique les DoT et malus en attente.
# Surchargée par Guerrier (gestion Rage).
# =======================================================
func debut_tour() -> void:
	# Recharge les PM au maximum
	pm_actuels = pm_max

	# Applique le malus de PM de la Tempête Électrique si actif.
	# On sauvegarde la valeur AVANT de la remettre à 0
	# pour pouvoir l'afficher correctement dans le print.
	if pm_malus_prochain_tour > 0:
		var malus_applique     : int = pm_malus_prochain_tour
		pm_actuels                   = max(0, pm_actuels - malus_applique)
		pm_malus_prochain_tour       = 0
		print("⚡ Malus Tempête : -%d PM ce tour" % malus_applique)

	# Réinitialise le verrou d'attaque
	a_attaque_ce_tour = false

	# Réduit le cooldown de tous les sorts de 1 tour
	for sort in sorts:
		sort.reduire_cooldown()

	# Applique les DoT actifs (hache empoisonnée, lame, etc.)
	appliquer_dots()

	# Réduit l'immobilisation restante (Gel, Piège)
	if tours_immobilise > 0:
		tours_immobilise -= 1
		print("❄️ Immobilisé encore %d tour(s)" % tours_immobilise)


# =======================================================
# PASSIF — Overridé dans chaque classe fille si nécessaire
# =======================================================
func utiliser_passif() -> void:
	pass
