# sort.gd
extends Resource

var id: String
var nom: String
var degats: int
var portee: int
var cooldown_max: int
var cooldown_actuel: int = 0
var cout_gold: int = 0
var cout_pm: int = 0          # ← AJOUT : PM consommés à l'utilisation
var ligne_de_vue: bool = false
var description: String

func est_disponible() -> bool:
	return cooldown_actuel <= 0

func declencher_cooldown():
	cooldown_actuel = cooldown_max

func reduire_cooldown():
	if cooldown_actuel > 0:
		cooldown_actuel -= 1

# Constructeur statique — cout_pm ajouté entre cout_gold et ligne_de_vue
static func creer(
	p_id: String,
	p_nom: String,
	p_degats: int,
	p_portee: int,
	p_cd: int,
	p_cout_gold: int,
	p_cout_pm: int,        # ← AJOUT (7ème paramètre)
	p_ligne_vue: bool,
	p_description: String
) -> Resource:
	var sort = new()
	sort.id = p_id
	sort.nom = p_nom
	sort.degats = p_degats
	sort.portee = p_portee
	sort.cooldown_max = p_cd
	sort.cout_gold = p_cout_gold
	sort.cout_pm = p_cout_pm   # ← AJOUT
	sort.ligne_de_vue = p_ligne_vue
	sort.description = p_description
	return sort
