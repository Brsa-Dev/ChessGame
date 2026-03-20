# =======================================================
# Handlers/sort_handler.gd
# -------------------------------------------------------
# Responsabilité UNIQUE : exécuter les sorts des joueurs.
#
#   - Dispatch vers chaque sort (utiliser_sort)
#   - Logique de chaque sort (Guerrier, Mage, Archer, Fripon)
#   - Helpers de combat (repousser, rebond, ligne de vue)
#   - Résolution des effets différés (météore, dérobade)
#
# NE gère PAS les inputs (c'est input_handler).
# NE gère PAS les effets de case (c'est effects_handler).
# =======================================================
extends Node


# =======================================================
# CONSTANTES — Sorts Guerrier
# =======================================================

const DEGATS_IMPACT_MUR       : int = 10  # Dégâts bonus si repoussé contre un mur
const CASES_REPOUSSE_BOUCLIER : int = 2   # Distance de repousse du Coup de Bouclier
const DUREE_MUR_TEMPORAIRE    : int = 2   # Tours avant disparition du Mur temporaire


# =======================================================
# CONSTANTES — Sorts Mage
# =======================================================

const DEGATS_METEORE       : int = 25  # Dégâts de base du Météore (+ bonus mage)
const RAYON_METEORE        : int = 1   # Rayon d'explosion (cases adjacentes incluses)
const DUREE_LAVE_METEORE   : int = 2   # Tours avant disparition des cases de lave
const DELAI_METEORE        : int = 3   # Tours avant l'explosion du Météore
const DUREE_GEL            : int = 2   # Tours d'immobilisation du sort Gel
const TEMPETE_MALUS_PORTEE : int = 2   # Réduction de portée infligée par Tempête Arcanique


# =======================================================
# CONSTANTES — Sorts Archer
# =======================================================

const DEGATS_REBOND_FLECHE  : int = 10  # Dégâts du rebond de la Flèche Rebondissante
const RAYON_REBOND_FLECHE   : int = 2   # Rayon de recherche du rebond (distance Manhattan)
const DEGATS_TIR_CIBLE_FORET: int = 60  # Dégâts du Tir Ciblé sur case forêt
const DUREE_FORET_PLUIE     : int = 2   # Tours de durée des forêts de la Pluie de Flèches
const COUT_GOLD_TIR_FORET   : int = 5


# =======================================================
# CONSTANTES — Sorts Fripon
# =======================================================

const DEGATS_RUEE            : int = 5   # Dégâts de la Ruée sur la cible
const DEGATS_DEROBADE_BASE   : int = 20  # Dégâts de base de l'explosion Dérobade
const DEGATS_LAME_DEROBADE   : int = 10  # Dégâts bonus Lame lors d'une explosion Dérobade
const DOT_LAME_DEGATS        : int = 5   # Dégâts par tour du DoT Lame Empoisonnée
const DOT_LAME_DUREE         : int = 3   # Durée en tours du DoT Lame Empoisonnée
const ATTAQUES_POUR_RUEE     : int = 3   # Nombre d'attaques pour déverrouiller la Ruée
const DUREE_MARQUE_DEROBADE  : int = 3   # Tours avant expiration de la marque Dérobade


# =======================================================
# CONSTANTES — Sorts inapplicables sur mine
# -------------------------------------------------------
# Sorts utilitaires, buffs, sorts de zone sur joueurs —
# ne peuvent pas cibler une mine d'or.
# =======================================================

const SORTS_INAPPLICABLES_SUR_MINE : Array[String] = [
	"guerrier_mur", "guerrier_rage",
	"mage_gel", "mage_tempete",
	"archer_piege",
	"fripon_derobade", "fripon_lame", "fripon_frenesie"
]


# =======================================================
# RÉFÉRENCES — Injectées par main.gd dans _ready()
# =======================================================

var board           : Node  = null  # board.gd — état du plateau
var renderer        : Node  = null  # renderer.gd — redraw visuel
var event_manager   : Node  = null  # event_manager.gd — mines, coffres
var effects_handler : Node  = null  # effects_handler.gd — effets de case
var joueurs         : Array[Node] = []  # [joueur1, joueur2, joueur3]
var log_ui          : Node  = null  # LogUI — historique des actions


# =======================================================
# ÉTAT — Listes partagées avec main.gd
# -------------------------------------------------------
# Injectées par référence dans _ready()
# =======================================================

var meteores_en_attente : Array[Dictionary] = []  # Météores en vol
var laves_temporaires   : Array[Dictionary] = []  # Cases de lave actives
var forets_temporaires  : Array[Dictionary] = []  # Forêts temporaires actives
var pieges_actifs       : Array[Dictionary] = []  # Pièges posés sur le plateau
var murs_temporaires    : Array[Dictionary] = []  # Murs temporaires actifs


# =======================================================
# POINT D'ENTRÉE — Utiliser un sort
# -------------------------------------------------------
# Appelée par input_handler après validation portée/PM/Gold.
# Retourne true si le sort a été utilisé avec succès.
# Retourne false si le sort échoue (cible invalide, etc.)
# =======================================================
func utiliser_sort(joueur: Node, sort: Sort, cible_x: int, cible_y: int) -> bool:
	var cible : Node = _get_joueur_en(cible_x, cible_y)

	# -------------------------------------------------------
	# CAS SPÉCIAL — Cible est une Mine
	# Certains sorts offensifs peuvent frapper une mine.
	# Les sorts utilitaires sont bloqués.
	# -------------------------------------------------------
	var mine : Dictionary = event_manager.get_mine_en(cible_x, cible_y)
	if mine != {} and cible == null:
		return _utiliser_sort_sur_mine(joueur, sort, cible_x, cible_y, mine)

	# Dispatch vers le sort correspondant
	return _dispatcher_sort(joueur, sort, cible, cible_x, cible_y)


# =======================================================
# DISPATCH SORTS
# =======================================================
func _dispatcher_sort(joueur: Node, sort: Sort, cible: Node, cible_x: int, cible_y: int) -> bool:
	match sort.id:

		# ---------------------------------------------------
		# GUERRIER
		# ---------------------------------------------------
		"guerrier_mur":       return _sort_guerrier_mur(joueur, sort, cible_x, cible_y)
		"guerrier_hache":     return _sort_guerrier_hache(joueur, sort, cible)
		"guerrier_bouclier":  return _sort_guerrier_bouclier(joueur, sort, cible)
		"guerrier_rage":      return _sort_guerrier_rage(joueur, sort)

		# ---------------------------------------------------
		# MAGE
		# ---------------------------------------------------
		"mage_boule_feu":  return _sort_mage_boule_feu(joueur, sort, cible)
		"mage_gel":        return _sort_mage_gel(joueur, sort, cible)
		"mage_meteore":    return _sort_mage_meteore(joueur, sort, cible_x, cible_y)
		"mage_tempete":    return _sort_mage_tempete(joueur, sort)

		# ---------------------------------------------------
		# ARCHER
		# ---------------------------------------------------
		"archer_fleche":        return _sort_archer_fleche(joueur, sort, cible, cible_x, cible_y)
		"archer_piege":         return _sort_archer_piege(joueur, sort, cible_x, cible_y)
		"archer_tir_cible":     return _sort_archer_tir_cible(joueur, sort, cible, cible_x, cible_y)
		"archer_pluie_fleches": return _sort_archer_pluie_fleches(joueur, sort, cible_x, cible_y)

		# ---------------------------------------------------
		# FRIPON
		# ---------------------------------------------------
		"fripon_ruee":     return _sort_fripon_ruee(joueur, sort, cible, cible_x, cible_y)
		"fripon_derobade": return _sort_fripon_derobade(joueur, sort, cible)
		"fripon_lame":     return _sort_fripon_lame(joueur, sort)
		"fripon_frenesie": return _sort_fripon_frenesie(joueur, sort)

	push_warning("sort_handler._dispatcher_sort() — sort inconnu : %s" % sort.id)
	return false


# =======================================================
# SORTS GUERRIER
# =======================================================

func _sort_guerrier_mur(joueur: Node, sort: Sort, cible_x: int, cible_y: int) -> bool:
	if _get_joueur_en(cible_x, cible_y) != null:
		return false
	if board.get_case(cible_x, cible_y) == board.CaseType.TOUR:
		return false

	_consommer_ressources(joueur, sort)

	# Mémorise le type original pour restauration après DUREE_MUR_TEMPORAIRE tours
	murs_temporaires.append({
		"x"             : cible_x,
		"y"             : cible_y,
		"type_original" : board.get_case(cible_x, cible_y),
		"tours_restants": DUREE_MUR_TEMPORAIRE,
		"lanceur"       : joueur
	})

	board.plateau[cible_x][cible_y] = board.CaseType.MUR
	renderer.rafraichir()
	_log("🧱 %s pose un Mur en (%d,%d)" % [joueur.name, cible_x, cible_y], joueur)
	return true


func _sort_guerrier_hache(joueur: Node, sort: Sort, cible: Node) -> bool:
	if not cible:
		return false
	if not _a_ligne_de_vue(joueur.grid_x, joueur.grid_y, cible.grid_x, cible.grid_y):
		return false
	_consommer_ressources(joueur, sort)
	var degats : int = sort.degats + joueur.bonus_degats_sorts
	cible.recevoir_degats(degats)
	cible.ajouter_dot("hache_empoisonnee", DOT_LAME_DEGATS, DOT_LAME_DUREE)
	joueur.gagner_gold_sur_degats(degats)
	_log("🪓 %s frappe %s — %d dmg + poison" % [joueur.name, cible.name, degats], joueur)
	return true


func _sort_guerrier_bouclier(joueur: Node, sort: Sort, cible: Node) -> bool:
	if not cible:
		return false
	_consommer_ressources(joueur, sort)
	var degats : int = sort.degats + joueur.bonus_degats_sorts
	cible.recevoir_degats(degats)
	joueur.gagner_gold_sur_degats(degats)

	var bloque_obstacle : bool = _repousser_joueur(joueur, cible, CASES_REPOUSSE_BOUCLIER)

	# Applique l'effet de la case d'arrivée (Lave, Eau, Forêt...)
	effects_handler.appliquer_effet_case(cible)

	renderer.rafraichir()

	if bloque_obstacle:
		cible.recevoir_degats(DEGATS_IMPACT_MUR)
		joueur.gagner_gold_sur_degats(DEGATS_IMPACT_MUR)
		_log("🛡️ %s repousse %s contre un mur — %d + %d dmg" % [joueur.name, cible.name, degats, DEGATS_IMPACT_MUR], joueur)
	else:
		_log("🛡️ %s repousse %s — %d dmg" % [joueur.name, cible.name, degats], joueur)
	return true


func _sort_guerrier_rage(joueur: Node, sort: Sort) -> bool:
	_consommer_ressources(joueur, sort)
	joueur.activer_rage()
	_log("😡 %s entre en Rage !" % joueur.name, joueur)
	return true


# =======================================================
# SORTS MAGE
# =======================================================

func _sort_mage_boule_feu(joueur: Node, sort: Sort, cible: Node) -> bool:
	if not cible:
		return false
	_consommer_ressources(joueur, sort)
	var degats : int = sort.degats + joueur.bonus_degats_sorts
	cible.recevoir_degats(degats)
	joueur.gagner_gold_sur_degats(degats)
	_log("🔥 %s — Boule de Feu sur %s — %d dmg" % [joueur.name, cible.name, degats], joueur)
	return true


func _sort_mage_gel(joueur: Node, sort: Sort, cible: Node) -> bool:
	if not cible:
		return false
	_consommer_ressources(joueur, sort)
	cible.tours_immobilise = DUREE_GEL
	_log("❄️ %s gèle %s — %d tours" % [joueur.name, cible.name, DUREE_GEL], joueur)
	return true


func _sort_mage_meteore(joueur: Node, sort: Sort, cible_x: int, cible_y: int) -> bool:
	_consommer_ressources(joueur, sort)
	meteores_en_attente.append({
		"cible_x"        : cible_x,
		"cible_y"        : cible_y,
		"tours_restants" : DELAI_METEORE,
		"lanceur"        : joueur
	})
	_log("☄️ %s — Météore en route vers (%d,%d) !" % [joueur.name, cible_x, cible_y], joueur)
	return true


func _sort_mage_tempete(joueur: Node, sort: Sort) -> bool:
	# Coût réduit par le Cristal de Mana si le Mage l'a acheté
	var cout_final : int = max(0, sort.cout_gold - joueur.reduction_cout_tempete)
	if joueur.gold < cout_final:
		return false

	# On déduit manuellement (le coût est modifié, pas sort.cout_gold)
	joueur.gold       -= cout_final
	joueur.pm_actuels -= sort.cout_pm
	sort.declencher_cooldown()

	# Applique les dégâts à tous les ennemis vivants
	for j in joueurs:
		if j == joueur or not j.est_place or j.est_mort:
			continue
		var degats : int = sort.degats + joueur.bonus_degats_sorts
		j.recevoir_degats(degats)
		j.attaque_portee = max(0, j.attaque_portee - TEMPETE_MALUS_PORTEE)
		joueur.gagner_gold_sur_degats(degats)

	_log("⚡ %s — Tempête Arcanique !" % joueur.name, joueur)
	return true


# =======================================================
# SORTS ARCHER
# =======================================================

func _sort_archer_fleche(joueur: Node, sort: Sort, cible: Node, cible_x: int, cible_y: int) -> bool:
	if not cible:
		return false
	if not _a_ligne_de_vue(joueur.grid_x, joueur.grid_y, cible_x, cible_y):
		return false

	_consommer_ressources(joueur, sort)
	var degats_principal : int = sort.degats + joueur.bonus_degats_sorts
	cible.recevoir_degats(degats_principal)
	joueur.gagner_gold_sur_degats(degats_principal)

	# Rebond sur la cible la plus proche dans un rayon de RAYON_REBOND_FLECHE cases
	var cible_rebond : Node = _trouver_cible_rebond(joueur, cible)
	if cible_rebond:
		cible_rebond.recevoir_degats(DEGATS_REBOND_FLECHE)
		joueur.gagner_gold_sur_degats(DEGATS_REBOND_FLECHE)
		_log("🏹 %s → %s — %d dmg (rebond → %s)" % [joueur.name, cible.name, degats_principal, cible_rebond.name], joueur)
	else:
		_log("🏹 %s → %s — %d dmg" % [joueur.name, cible.name, degats_principal], joueur)
	return true


func _sort_archer_piege(joueur: Node, sort: Sort, cible_x: int, cible_y: int) -> bool:
	if _get_joueur_en(cible_x, cible_y) != null:
		return false
	if board.get_case(cible_x, cible_y) in [board.CaseType.VIDE, board.CaseType.MUR]:
		return false

	_consommer_ressources(joueur, sort)
	pieges_actifs.append({ "x": cible_x, "y": cible_y, "poseur": joueur })
	renderer.rafraichir()
	_log("🪤 %s pose un Piège en (%d,%d)" % [joueur.name, cible_x, cible_y], joueur)
	return true


func _sort_archer_tir_cible(joueur: Node, sort: Sort, cible: Node, cible_x: int, cible_y: int) -> bool:
	if not cible:
		return false
	if not _a_ligne_de_vue(joueur.grid_x, joueur.grid_y, cible_x, cible_y):
		return false

	var est_en_foret : bool = board.get_case(cible_x, cible_y) == board.CaseType.FORET

	# Vérifie le Gold supplémentaire requis si la cible est en Forêt
	if est_en_foret and joueur.gold < COUT_GOLD_TIR_FORET:
		return false

	_consommer_ressources(joueur, sort)

	# Déduit le coût Gold supplémentaire Forêt après les ressources de base
	if est_en_foret:
		joueur.gold -= COUT_GOLD_TIR_FORET

	var degats_finaux : int = DEGATS_TIR_CIBLE_FORET if est_en_foret else (sort.degats + joueur.bonus_degats_sorts)
	cible.recevoir_degats(degats_finaux)
	joueur.gagner_gold_sur_degats(degats_finaux)
	_log("🎯 %s — Tir Ciblé sur %s — %d dmg%s" % [joueur.name, cible.name, degats_finaux, " (forêt)" if est_en_foret else ""], joueur)
	return true


func _sort_archer_pluie_fleches(joueur: Node, sort: Sort, cible_x: int, cible_y: int) -> bool:
	_consommer_ressources(joueur, sort)

	# Transforme les cases dans un rayon 1 en Forêt temporaire
	var cases_transformees : Array[Dictionary] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var x : int = cible_x + dx
			var y : int = cible_y + dy
			if x < 0 or x >= board.TAILLE_PLATEAU or y < 0 or y >= board.TAILLE_PLATEAU:
				continue
			if board.get_case(x, y) in [board.CaseType.VIDE, board.CaseType.MUR, board.CaseType.TOUR]:
				continue
			cases_transformees.append({ "x": x, "y": y, "type_original": board.get_case(x, y) })
			board.plateau[x][y] = board.CaseType.FORET

	forets_temporaires.append({
		"cases"          : cases_transformees,
		"tours_restants" : DUREE_FORET_PLUIE,
		"lanceur"        : joueur
	})

	renderer.rafraichir()
	_log("🌧 %s — Pluie de Flèches en (%d,%d) !" % [joueur.name, cible_x, cible_y], joueur)
	return true


# =======================================================
# SORTS FRIPON
# =======================================================

func _sort_fripon_ruee(joueur: Node, sort: Sort, cible: Node, cible_x: int, cible_y: int) -> bool:
	var type_case : int = board.get_case(cible_x, cible_y)
	if type_case in [board.CaseType.VIDE, board.CaseType.MUR]:
		return false

	# La Ruée nécessite d'avoir été rechargée (ATTAQUES_POUR_RUEE attaques)
	if not joueur.ruee_disponible:
		return false

	var case_arrivee : Vector2i

	if cible:
		# Cible ennemie → on se place à côté et on inflige des dégâts
		case_arrivee = _trouver_case_libre_pres(cible_x, cible_y, joueur)
		if case_arrivee == Vector2i(-1, -1):
			return false
		var degats : int = sort.degats + joueur.bonus_degats_sorts
		cible.recevoir_degats(degats)
		joueur.gagner_gold_sur_degats(degats)
	else:
		# Case libre → téléportation directe
		case_arrivee = Vector2i(cible_x, cible_y)

	_consommer_ressources(joueur, sort)
	joueur.ruee_disponible      = false
	joueur.attaques_depuis_ruee = 0

	# Repositionne le joueur
	board.liberer_case(joueur.grid_x, joueur.grid_y)
	joueur.grid_x = case_arrivee.x
	joueur.grid_y = case_arrivee.y
	board.occuper_case(joueur.grid_x, joueur.grid_y)

	# La Ruée compte comme un déplacement → le Fripon peut réattaquer
	joueur.a_attaque_ce_tour = false

	effects_handler.appliquer_effet_case(joueur)
	renderer.rafraichir()
	if cible:
		_log("⚡ %s — Ruée sur %s — %d dmg" % [joueur.name, cible.name, sort.degats + joueur.bonus_degats_sorts], joueur)
	else:
		_log("⚡ %s — Ruée vers (%d,%d)" % [joueur.name, cible_x, cible_y], joueur)
	return true


func _sort_fripon_derobade(joueur: Node, sort: Sort, cible: Node) -> bool:
	# Si une marque est déjà active → explosion immédiate (fallback)
	# Le cas principal est géré dans input_handler via _exploser_marque_derobade()
	if joueur.get("marque_cible") != null:
		exploser_marque_derobade(joueur)
		return true

	# Sinon → pose de la marque sur l'ennemi ciblé
	if not cible:
		return false

	joueur.pm_actuels            -= sort.cout_pm
	sort.declencher_cooldown()
	joueur.marque_cible          = cible
	joueur.marque_tours_restants = DUREE_MARQUE_DEROBADE
	_log("👤 %s — Dérobade posée sur %s" % [joueur.name, cible.name], joueur)
	return true


func _sort_fripon_lame(joueur: Node, sort: Sort) -> bool:
	joueur.pm_actuels -= sort.cout_pm
	sort.declencher_cooldown()
	joueur.lame_active = true
	_log("🗡️ %s — Lame Empoisonnée activée" % joueur.name, joueur)
	return true


func _sort_fripon_frenesie(joueur: Node, sort: Sort) -> bool:
	# Coût réduit par la Potion de Frénésie si achetée
	var cout_final : int = max(0, sort.cout_gold - joueur.reduction_cout_frenesie)
	if joueur.gold < cout_final:
		return false

	joueur.gold       -= cout_final
	joueur.pm_actuels -= sort.cout_pm
	sort.declencher_cooldown()
	joueur.frenesie_active = true
	_log("🌀 %s — Frénésie activée !" % joueur.name, joueur)
	return true


# =======================================================
# SORTS SUR MINE
# -------------------------------------------------------
# Redirige les sorts offensifs vers une mine d'or.
# Les sorts utilitaires sont bloqués proprement.
# =======================================================
func _utiliser_sort_sur_mine(joueur: Node, sort: Sort, cible_x: int, cible_y: int, _mine: Dictionary) -> bool:
	if sort.id in SORTS_INAPPLICABLES_SUR_MINE:
		return false

	# Vérifie portée et ressources avant d'attaquer la mine
	var portee_effective : int = sort.portee + joueur.bonus_range_sorts
	var distance         : int = abs(cible_x - joueur.grid_x) + abs(cible_y - joueur.grid_y)
	if sort.portee != 0 and distance > portee_effective:
		return false
	if joueur.pm_actuels < sort.cout_pm:
		return false
	if joueur.gold < sort.cout_gold:
		return false

	var degats : int = sort.degats + joueur.bonus_degats_sorts
	joueur.pm_actuels -= sort.cout_pm
	joueur.gold       -= sort.cout_gold
	sort.declencher_cooldown()
	joueur.gagner_gold_sur_degats(degats)
	event_manager.attaquer_mine(cible_x, cible_y, degats, joueur)
	renderer.rafraichir()
	return true


# =======================================================
# RÉSOLUTION DES EFFETS DIFFÉRÉS
# =======================================================

# -------------------------------------------------------
# Explose un météore sur sa case cible.
# Zone d'effet 3x3 autour du point d'impact.
# Les cases touchées deviennent de la lave temporaire.
# -------------------------------------------------------
func exploser_meteore(meteore: Dictionary) -> void:
	var cx      : int  = meteore["cible_x"]
	var cy      : int  = meteore["cible_y"]
	var lanceur : Node = meteore["lanceur"]

	var cases_transformees : Array[Dictionary] = []

	for dx in range(-RAYON_METEORE, RAYON_METEORE + 1):
		for dy in range(-RAYON_METEORE, RAYON_METEORE + 1):
			var x : int = cx + dx
			var y : int = cy + dy
			if x < 0 or x >= board.TAILLE_PLATEAU or y < 0 or y >= board.TAILLE_PLATEAU:
				continue

			# Inflige des dégâts à tout joueur dans la zone
			for j in joueurs:
				if j.est_place and not j.est_mort and j.grid_x == x and j.grid_y == y:
					var degats : int = DEGATS_METEORE + lanceur.bonus_degats_sorts
					j.recevoir_degats(degats)
					lanceur.gagner_gold_sur_degats(degats)

			# Les cases Tour ne sont pas transformées
			if board.get_case(x, y) == board.CaseType.TOUR:
				continue

			cases_transformees.append({ "x": x, "y": y, "type_original": board.get_case(x, y) })
			board.plateau[x][y] = board.CaseType.LAVE

	laves_temporaires.append({ "cases": cases_transformees, "tours_restants": DUREE_LAVE_METEORE })
	renderer.rafraichir()


# -------------------------------------------------------
# Explose la marque Dérobade du Fripon.
# Inflige des dégâts à la cible marquée.
# Synergie Lame : +DEGATS_LAME_DEROBADE dmg + DoT si la Lame est active.
# -------------------------------------------------------
func exploser_marque_derobade(fripon: Node) -> void:
	var cible : Node = fripon.marque_cible
	if not cible or cible.est_mort:
		fripon.marque_cible = null
		return

	var degats_base : int = DEGATS_DEROBADE_BASE + fripon.bonus_degats_sorts
	cible.recevoir_degats(degats_base)
	fripon.gagner_gold_sur_degats(degats_base)

	# Synergie Lame Empoisonnée
	if fripon.lame_active:
		cible.recevoir_degats(DEGATS_LAME_DEROBADE)
		fripon.gagner_gold_sur_degats(DEGATS_LAME_DEROBADE)
		# ID unique pour permettre le cumul / refresh du DoT
		cible.ajouter_dot("lame_derobade_%d" % Time.get_ticks_msec(), DOT_LAME_DEGATS, DOT_LAME_DUREE)
		fripon.lame_active = false

	# Synergie Ruée — l'explosion compte comme une attaque
	fripon.attaques_depuis_ruee += 1
	if not fripon.ruee_disponible and fripon.attaques_depuis_ruee >= ATTAQUES_POUR_RUEE:
		fripon.ruee_disponible = true

	# On efface la marque après l'explosion
	fripon.marque_cible = null
	renderer.rafraichir()


# =======================================================
# HELPERS DE COMBAT
# =======================================================

# -------------------------------------------------------
# Repousse un joueur de nb_cases cases dans la direction
# attaquant → cible. Retourne true si bloqué par un mur.
# -------------------------------------------------------
func _repousser_joueur(attaquant: Node, cible: Node, nb_cases: int) -> bool:
	var dir_x : int  = cible.grid_x - attaquant.grid_x
	var dir_y : int  = cible.grid_y - attaquant.grid_y
	if dir_x != 0: dir_x = dir_x / abs(dir_x)
	if dir_y != 0: dir_y = dir_y / abs(dir_y)

	var pos_x           : int  = cible.grid_x
	var pos_y           : int  = cible.grid_y
	var bloque_obstacle : bool = false

	for _i in range(nb_cases):
		var test_x : int = pos_x + dir_x
		var test_y : int = pos_y + dir_y
		if test_x < 0 or test_x >= board.TAILLE_PLATEAU or test_y < 0 or test_y >= board.TAILLE_PLATEAU:
			bloque_obstacle = true
			break
		var type_case : int = board.get_case(test_x, test_y)
		# TOUR ajoutée — inflige les dégâts d'impact sans que la cible y entre
		if type_case in [board.CaseType.MUR, board.CaseType.VIDE, board.CaseType.TOUR]:
			bloque_obstacle = true
			break
		if board.case_occupee(test_x, test_y):
			break
		pos_x = test_x
		pos_y = test_y

	if pos_x != cible.grid_x or pos_y != cible.grid_y:
		board.liberer_case(cible.grid_x, cible.grid_y)
		cible.grid_x = pos_x
		cible.grid_y = pos_y
		board.occuper_case(pos_x, pos_y)

	return bloque_obstacle


# -------------------------------------------------------
# Trouve la cible du rebond de la Flèche Rebondissante.
# Cherche un ennemi dans un rayon autour de la CIBLE INITIALE.
# Exclut le lanceur et la cible initiale elle-même.
# -------------------------------------------------------
func _trouver_cible_rebond(lanceur: Node, cible_initiale: Node) -> Node:
	var meilleure_cible    : Node = null
	var meilleure_distance : int  = 999

	for j in joueurs:
		if j == cible_initiale or j == lanceur:
			continue
		if not j.est_place or j.est_mort:
			continue

		# Distance depuis la CIBLE (pas depuis le lanceur)
		var distance : int = abs(j.grid_x - cible_initiale.grid_x) + abs(j.grid_y - cible_initiale.grid_y)
		if distance <= RAYON_REBOND_FLECHE and distance < meilleure_distance:
			meilleure_distance = distance
			meilleure_cible    = j

	return meilleure_cible


# -------------------------------------------------------
# Vérifie la ligne de vue entre deux cases (Bresenham).
# Retourne false si une case VIDE ou MUR bloque le chemin.
# -------------------------------------------------------
func _a_ligne_de_vue(x1: int, y1: int, x2: int, y2: int) -> bool:
	var dx  : int = abs(x2 - x1)
	var dy  : int = abs(y2 - y1)
	var sx  : int = 1 if x1 < x2 else -1
	var sy  : int = 1 if y1 < y2 else -1
	var err : int = dx - dy
	var cx  : int = x1
	var cy  : int = y1

	while cx != x2 or cy != y2:
		# On saute la case de départ (le lanceur lui-même)
		if not (cx == x1 and cy == y1):
			var type_case : int = board.get_case(cx, cy)
			if type_case in [board.CaseType.MUR, board.CaseType.VIDE]:
				return false

		var e2 : int = 2 * err
		if e2 > -dy:
			err -= dy
			cx  += sx
		if e2 < dx:
			err += dx
			cy  += sy

	return true


# -------------------------------------------------------
# Trouve une case libre adjacente à (x, y).
# Utilisée par la Ruée pour se placer à côté d'un ennemi.
# Retourne Vector2i(-1, -1) si aucune case disponible.
# -------------------------------------------------------
func _trouver_case_libre_pres(x: int, y: int, joueur_qui_cherche: Node) -> Vector2i:
	var directions : Array[Vector2i] = [
		Vector2i(0, -1),  # Haut
		Vector2i(0,  1),  # Bas
		Vector2i(-1, 0),  # Gauche
		Vector2i( 1, 0),  # Droite
	]
	for dir in directions:
		var tx : int = x + dir.x
		var ty : int = y + dir.y
		if tx < 0 or tx >= board.TAILLE_PLATEAU or ty < 0 or ty >= board.TAILLE_PLATEAU:
			continue
		var type_case : int = board.get_case(tx, ty)
		if type_case in [board.CaseType.VIDE, board.CaseType.MUR]:
			continue
		if board.case_occupee(tx, ty) and not (tx == joueur_qui_cherche.grid_x and ty == joueur_qui_cherche.grid_y):
			continue
		return Vector2i(tx, ty)
	return Vector2i(-1, -1)


# =======================================================
# HELPERS INTERNES
# =======================================================

# -------------------------------------------------------
# Consomme PM, Gold et déclenche le cooldown d'un sort.
# Factorisé pour éviter la répétition dans chaque sort.
# -------------------------------------------------------
func _consommer_ressources(joueur: Node, sort: Sort) -> void:
	joueur.pm_actuels -= sort.cout_pm
	joueur.gold       -= sort.cout_gold
	sort.declencher_cooldown()


func _log(message: String, joueur: Node = null) -> void:
	if log_ui == null:
		return
	log_ui.ajouter(message, joueur)


# -------------------------------------------------------
# Retourne le joueur vivant présent sur la case (x, y).
# Retourne null si personne ou si le joueur est mort.
# -------------------------------------------------------
func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in joueurs:
		var est_actif : bool = joueur.est_place and not joueur.est_mort
		if est_actif and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null
