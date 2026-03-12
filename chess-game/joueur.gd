extends Node

# -----------------------------------------------
# JOUEUR — Classe de base
# -----------------------------------------------
signal mort

# Indique si le joueur est éliminé
var est_mort: bool = false

var grid_x: int = 0
var grid_y: int = 0
var est_place: bool = false

var pm_max: int = 5
var pm_actuels: int = 5

var hp_max: int = 100
var hp_actuels: int = 100

var gold: int = 0
var niveau: int = 1

# -----------------------------------------------
# Attaque de base — valeurs génériques
# Seront overridées par chaque classe fille
# -----------------------------------------------
var attaque_degats: int = 10        # Dégâts infligés
var attaque_portee: int = 1         # Portée en cases (distance de Manhattan)
var attaque_cout_pm: int = 1        # PM consommés par attaque
var a_attaque_ce_tour: bool = false # True si le joueur a déjà attaqué ce tour

# -----------------------------------------------
# Boutique & dépences de Golds
# -----------------------------------------------

var inventaire: Array = []              # Liste des items achetés
var achats_par_item: Dictionary = {}    # { "elixir_gold": 1, ... }
var resistance_degats: float = 0.0     # Cumulable (ex: 0.10 = 10%)

# Résistance temporaire liée à la case Forêt
# Remise à 0 quand le joueur quitte la case
var resistance_case: float = 0.0

# Bonus de Range sur les sorts (actif sur une case TOUR)
var bonus_range_sorts: int = 0

# Bonus de dégâts sur les sorts (Mage)
var bonus_degats_sorts: int = 0

# Liste des sorts du joueur (initialisée par chaque classe fille)
var sorts: Array = []

# Index du sort sélectionné (-1 = aucun)
var sort_selectionne: int = -1

# Tableau des DoT actifs sur ce joueur
# Format : { "source_id": { "degats": 5, "tours_restants": 3 } }
var dots_actifs: Dictionary = {}

# -----------------------------------------------
# Effets de statut
# -----------------------------------------------

# Nombre de tours où le joueur est immobilisé (Gel)
var tours_immobilise: int = 0

# Sorts en attente d'exécution différée
# Format : [{ "id": "mage_meteore", "cible_x": 3, "cible_y": 4, "tours_restants": 2, "lanceur": joueur }]
var sorts_en_attente: Array = []

# -----------------------------------------------
# Place le joueur sur une case de la grille
# -----------------------------------------------
func placer(x: int, y: int):
	grid_x = x
	grid_y = y
	est_place = true

# -----------------------------------------------
# Retourne true si le joueur peut encore bouger
# -----------------------------------------------
func peut_se_deplacer() -> bool:
	return pm_actuels > 0 and tours_immobilise <= 0

# -----------------------------------------------
# Vérifie si la case (x, y) est accessible
# -----------------------------------------------
func peut_se_deplacer_vers(x: int, y: int) -> bool:
	if not peut_se_deplacer():
		return false
	var distance = abs(x - grid_x) + abs(y - grid_y)
	return distance <= pm_actuels

# -----------------------------------------------
# Déplace le joueur et consomme les PM
# -----------------------------------------------
func deplacer(x: int, y: int, cout_pm: int = -1):
	if peut_se_deplacer_vers(x, y):
		# Si cout_pm est précisé (ex: Forêt = 2), on l'utilise
		# Sinon on utilise la distance normale
		var distance = abs(x - grid_x) + abs(y - grid_y) if cout_pm == -1 else cout_pm
		pm_actuels -= distance
		grid_x = x
		grid_y = y

# -----------------------------------------------
# Retourne true si le joueur peut attaquer la cible
# -----------------------------------------------
func peut_attaquer(cible_x: int, cible_y: int) -> bool:
	if a_attaque_ce_tour:
		return false
	if pm_actuels < attaque_cout_pm:
		return false
	var distance = abs(cible_x - grid_x) + abs(cible_y - grid_y)
	return distance <= attaque_portee

# -----------------------------------------------
# Attaque une cible et retourne les dégâts infligés
# -----------------------------------------------
func attaquer(cible: Node) -> int:
	if not peut_attaquer(cible.grid_x, cible.grid_y):
		return 0
	pm_actuels -= attaque_cout_pm
	a_attaque_ce_tour = true
	cible.recevoir_degats(attaque_degats)
	# Gain de gold centralisé — s'applique aussi aux sorts plus tard
	gagner_gold_sur_degats(attaque_degats)
	print("Attaque ! ", attaque_degats, " dégâts — PM restants : ", pm_actuels)
	return attaque_degats

# -----------------------------------------------
# Reçoit des dégâts
# -----------------------------------------------
func recevoir_degats(degats: int):
	# On cumule la résistance de l'Amulette + celle de la Forêt
	var resistance_totale = resistance_degats + resistance_case
	var degats_reduits = int(degats * (1.0 - resistance_totale))
	hp_actuels -= degats_reduits
	hp_actuels = max(0, hp_actuels)
	print("HP restants : ", hp_actuels, " / ", hp_max, " (", degats_reduits, " dégâts reçus)")
	if hp_actuels <= 0:
		est_mort = true
		print("Joueur éliminé !")
		emit_signal("mort")

func ajouter_dot(source_id: String, degats: int, duree: int):
	dots_actifs[source_id] = {
		"degats": degats,
		"tours_restants": duree
	}
	print("☠️ DoT appliqué : ", degats, " dégâts/tour pendant ", duree, " tours")

# -----------------------------------------------
# Applique les DoT actifs — appelée dans debut_tour()
# -----------------------------------------------
func appliquer_dots():
	var a_supprimer = []
	for source_id in dots_actifs:
		var dot = dots_actifs[source_id]
		recevoir_degats(dot["degats"])
		dot["tours_restants"] -= 1
		print("☠️ DoT (", source_id, ") — ", dot["tours_restants"], " tours restants")
		if dot["tours_restants"] <= 0:
			a_supprimer.append(source_id)
	# Supprime les DoT expirés
	for source_id in a_supprimer:
		dots_actifs.erase(source_id)
		
		
# -----------------------------------------------
# Ajoute un sort en attente (ex: Météore)
# -----------------------------------------------
func ajouter_sort_en_attente(sort_id: String, cible_x: int, cible_y: int, delai: int, lanceur: Node):
	sorts_en_attente.append({
		"id": sort_id,
		"cible_x": cible_x,
		"cible_y": cible_y,
		"tours_restants": delai,
		"lanceur": lanceur
	})
	print("⏳ Sort en attente : ", sort_id, " — impact dans ", delai, " tours")
		
		
# -----------------------------------------------
# Méthode centralisée pour gagner du Gold
# Appelée par TOUTES les sources de dégâts :
# attaque de base, sorts, effets, etc.
# +1 Gold tous les 10 dégâts infligés
# -----------------------------------------------
func gagner_gold_sur_degats(degats: int):
	var gold_gagne = degats / 10
	if gold_gagne > 0:
		gold += gold_gagne
		print("+", gold_gagne, " Gold ! Total : ", gold)

# -----------------------------------------------
# Réinitialise les PM et l'attaque au début du tour
# -----------------------------------------------
func debut_tour():
	pm_actuels = pm_max
	a_attaque_ce_tour = false
	for sort in sorts:
		sort.reduire_cooldown()
	appliquer_dots()
	# Réduit l'immobilisation
	if tours_immobilise > 0:
		tours_immobilise -= 1
		print("❄️ Immobilisé encore ", tours_immobilise, " tour(s)")
	# Réduit le délai des sorts en attente
	_reduire_sorts_en_attente()

func _reduire_sorts_en_attente() -> Array:
	var prets = []
	for sort_attente in sorts_en_attente:
		sort_attente["tours_restants"] -= 1
		if sort_attente["tours_restants"] <= 0:
			prets.append(sort_attente)
	# Retire les sorts prêts de la liste d'attente
	for sort_attente in prets:
		sorts_en_attente.erase(sort_attente)
	return prets
	
# -----------------------------------------------
# Overridé dans chaque classe fille
# -----------------------------------------------
func utiliser_passif():
	pass
