# sort.gd
# -----------------------------------------------
# SORT — Structure de données d'un sort
# Hérite de Resource, léger et réutilisable
# -----------------------------------------------
extends Resource

var id: String           # Identifiant unique ex: "boule_de_feu"
var nom: String          # Nom affiché en UI
var degats: int          # Dégâts infligés (0 si sort utilitaire)
var portee: int          # Portée en cases (distance de Manhattan)
var cooldown_max: int    # Nombre de tours avant de pouvoir réutiliser
var cooldown_actuel: int = 0  # 0 = disponible, >0 = en recharge
var cout_gold: int = 0   # Coût en gold pour utiliser le sort
var ligne_de_vue: bool = false  # Nécessite une ligne de vue ?
var description: String  # Texte affiché en UI

# -----------------------------------------------
# Retourne true si le sort est utilisable
# -----------------------------------------------
func est_disponible() -> bool:
	return cooldown_actuel <= 0

# -----------------------------------------------
# Déclenche le cooldown après utilisation
# -----------------------------------------------
func declencher_cooldown():
	cooldown_actuel = cooldown_max

# -----------------------------------------------
# Réduit le cooldown d'un tour
# Appelée par joueur.gd au début de chaque tour
# -----------------------------------------------
func reduire_cooldown():
	if cooldown_actuel > 0:
		cooldown_actuel -= 1

# -----------------------------------------------
# Constructeur statique
# -----------------------------------------------
static func creer(p_id, p_nom, p_degats, p_portee, p_cd, p_cout_gold, p_ligne_vue, p_description) -> Resource:
	var sort = new()
	sort.id = p_id
	sort.nom = p_nom
	sort.degats = p_degats
	sort.portee = p_portee
	sort.cooldown_max = p_cd
	sort.cout_gold = p_cout_gold
	sort.ligne_de_vue = p_ligne_vue
	sort.description = p_description
	return sort
