extends Node2D

@onready var board = $Board
@onready var renderer = $Renderer
@onready var joueur1 = $Joueur1
@onready var joueur2 = $Joueur2
@onready var joueur3 = $Joueur3
@onready var tour_manager = $TourManager
@onready var bouton_fin_tour = $UI/BoutonFinTour
@onready var shop_manager = $ShopManager
@onready var shop_ui = $ShopUI

var joueur_selectionne: bool = false
var sort_selectionne: int = -1
var index_joueur_boutique: int = 0

# Météores en attente d'explosion
# Format : [{ "cible_x": 3, "cible_y": 4, "tours_restants": 2, "lanceur": joueur }]
var meteores_en_attente: Array = []

# Cases transformées en Lave par un Météore
# Mémorise le type ORIGINAL pour restauration après 1 tour global
var laves_temporaires: Array = []

# Pièges posés par l'Archer sur le plateau
# Format : [{ "x": 3, "y": 4, "poseur": joueur }]
# Invisibles pour l'ennemi — déclenchés au déplacement
var pieges_actifs: Array = []

# Cases transformées en Forêt par la Pluie de Flèches
# Même système que laves_temporaires — restaurées après 2 tours globaux
var forets_temporaires: Array = []

# -----------------------------------------------
func _ready():
	renderer.board = board
	renderer.joueurs = [joueur1, joueur2, joueur3]          # ← joueur3 ajouté
	tour_manager.initialiser([joueur1, joueur2, joueur3])   # ← joueur3 ajouté
	renderer.joueur_actif = tour_manager.get_joueur_actif()
	bouton_fin_tour.pressed.connect(fin_de_tour)
	
	joueur1.mort.connect(_on_joueur_mort.bind(joueur1))
	joueur2.mort.connect(_on_joueur_mort.bind(joueur2))
	joueur3.mort.connect(_on_joueur_mort.bind(joueur3))     # ← ajouté
	
	tour_manager.phase_boutique.connect(_on_phase_boutique)
	shop_ui.boutique_fermee.connect(_on_boutique_fermee)
	shop_ui.shop_manager = shop_manager
	tour_manager.tour_global_termine.connect(_on_tour_global_termine)
	
	renderer.queue_redraw()
	print("Main prêt !")

# -----------------------------------------------
# Boutique
# -----------------------------------------------
func _on_phase_boutique(_numero_tour: int):
	index_joueur_boutique = 0
	shop_manager.ouvrir_boutique()
	bouton_fin_tour.disabled = true
	shop_ui.ouvrir(joueur1)

func _on_boutique_fermee():
	index_joueur_boutique += 1
	var joueurs_liste = [joueur1, joueur2, joueur3]
	if index_joueur_boutique < joueurs_liste.size():
		shop_ui.ouvrir(joueurs_liste[index_joueur_boutique])
	else:
		bouton_fin_tour.disabled = false
		print("=== Phase boutique terminée — La partie reprend ===")
# -----------------------------------------------
# Gestion des inputs
# -----------------------------------------------
func _input(event):
	if event is InputEventKey and event.pressed:
		var joueur_actif = tour_manager.get_joueur_actif()
		
		if not joueur_selectionne:
			return
		
		var index = -1
		if event.is_action("sort_1"):   index = 0
		elif event.is_action("sort_2"): index = 1
		elif event.is_action("sort_3"): index = 2
		elif event.is_action("sort_4"): index = 3
		
		if index >= 0 and index < joueur_actif.sorts.size():
			var sort = joueur_actif.sorts[index]
			
			if not sort.est_disponible():
				print("Sort en recharge ! (", sort.cooldown_actuel, " tours restants)")
				return
			if joueur_actif.gold < sort.cout_gold:
				print("Pas assez de Gold pour ce sort !")
				return
			# Vérifie les PM AVANT de sélectionner le sort
			if joueur_actif.pm_actuels < sort.cout_pm:
				print("Pas assez de PM ! (", sort.cout_pm, " requis, ", joueur_actif.pm_actuels, " restants)")
				return
			
			if sort_selectionne == index:
				sort_selectionne = -1
				print("Sort désélectionné")
			else:
				sort_selectionne = index
				print("Sort sélectionné : ", sort.nom, " — Portée : ", sort.portee)
			
			renderer.sort_selectionne = sort_selectionne
			renderer.queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed:
		var cell = renderer.screen_to_grid(event.position)
		var joueur_actif = tour_manager.get_joueur_actif()

		if cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 8:
			if joueur_selectionne:
				joueur_selectionne = false
				sort_selectionne = -1
				renderer.joueur_selectionne = false
				renderer.sort_selectionne = -1
				renderer.queue_redraw()
			return

		if not joueur_actif.est_place:
			if not board.case_occupee(cell.x, cell.y):
				board.occuper_case(cell.x, cell.y)
				joueur_actif.placer(cell.x, cell.y)
				print("Joueur placé en (", cell.x, ", ", cell.y, ")")
			else:
				print("Case déjà occupée !")

		elif not joueur_selectionne:
			if cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				if joueur_actif.peut_se_deplacer() or not joueur_actif.a_attaque_ce_tour:
					joueur_selectionne = true
					print("Joueur sélectionné — PM : ", joueur_actif.pm_actuels)
				else:
					print("Plus de PM et déjà attaqué !")

		else:
			if sort_selectionne >= 0:
				var sort = joueur_actif.sorts[sort_selectionne]
				var portee_effective = sort.portee + joueur_actif.bonus_range_sorts
				var distance = abs(cell.x - joueur_actif.grid_x) + abs(cell.y - joueur_actif.grid_y)
				var a_portee = (sort.portee == 0) or (distance <= portee_effective)
				
				if a_portee:
					var sort_utilise = _utiliser_sort(joueur_actif, sort, cell.x, cell.y)
					if sort_utilise:
						sort_selectionne = -1
						renderer.sort_selectionne = -1
						joueur_selectionne = false
				else:
					print("Cible hors de portée du sort !")
				
				renderer.queue_redraw()
				return

			elif cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				joueur_selectionne = false
				print("Joueur désélectionné")

			elif _get_joueur_en(cell.x, cell.y) != null:
				var cible = _get_joueur_en(cell.x, cell.y)
				if joueur_actif.peut_attaquer(cell.x, cell.y):
					joueur_actif.attaquer(cible)
					joueur_selectionne = false
				else:
					if joueur_actif.a_attaque_ce_tour:
						print("Déjà attaqué ce tour !")
					elif joueur_actif.pm_actuels < joueur_actif.attaque_cout_pm:
						print("Pas assez de PM !")
					else:
						print("Cible hors de portée !")

			elif joueur_actif.peut_se_deplacer_vers(cell.x, cell.y):
				var type_case = board.get_case(cell.x, cell.y)
				if type_case == board.CaseType.VIDE or type_case == board.CaseType.MUR:
					print("Case infranchissable !")
				elif not board.case_occupee(cell.x, cell.y):
					board.liberer_case(joueur_actif.grid_x, joueur_actif.grid_y)
					var type_arrivee = board.get_case(cell.x, cell.y)
					var cout = 2 if type_arrivee == board.CaseType.FORET else -1
					joueur_actif.deplacer(cell.x, cell.y, cout)
					if joueur_actif.get("s_est_deplace_ce_tour") != null:
						joueur_actif.s_est_deplace_ce_tour = true
					_appliquer_effet_case(joueur_actif)
					# Vérifie si le joueur atterrit sur un piège ennemi
					_verifier_pieges(joueur_actif)
					board.occuper_case(joueur_actif.grid_x, joueur_actif.grid_y)
					joueur_selectionne = false
					print("Déplacé en (", cell.x, ", ", cell.y, ") — PM : ", joueur_actif.pm_actuels)
				else:
					print("Case occupée !")
			else:
				print("Case inaccessible !")

		renderer.joueur_actif = joueur_actif
		renderer.joueur_selectionne = joueur_selectionne
		renderer.queue_redraw()

# -----------------------------------------------
# Fin de tour individuel — effets persistants uniquement
# Les météores et laves sont gérés dans _on_tour_global_termine()
# -----------------------------------------------
func fin_de_tour():
	joueur_selectionne = false
	sort_selectionne = -1
	renderer.sort_selectionne = -1
	
	var joueur_qui_finit = tour_manager.get_joueur_actif()
	if joueur_qui_finit.est_place:
		_appliquer_effets_persistants(joueur_qui_finit)
	
	tour_manager.passer_au_tour_suivant()
	var joueur_actif = tour_manager.get_joueur_actif()
	print("--- Tour du Joueur ", tour_manager.index_joueur_actif + 1, " ---")
	renderer.joueur_actif = joueur_actif
	renderer.joueur_selectionne = false
	renderer.queue_redraw()

# -----------------------------------------------
# Appelée UNE FOIS par tour global
# (quand tous les joueurs ont joué)
# C'est ici qu'on décrémente météores et laves
# -----------------------------------------------
func _on_tour_global_termine(_numero_tour: int):
	print("=== Fin du tour global ", _numero_tour, " — Traitement météores/laves ===")
	
	# Décompte des météores — explose après 2 tours globaux
	var meteores_a_supprimer = []
	for meteore in meteores_en_attente:
		meteore["tours_restants"] -= 1
		print("☄️ Météore — ", meteore["tours_restants"], " tour(s) global(aux) avant impact")
		if meteore["tours_restants"] <= 0:
			_exploser_meteore(meteore)
			meteores_a_supprimer.append(meteore)
	for m in meteores_a_supprimer:
		meteores_en_attente.erase(m)
	
	# Décompte des laves — disparaît après 1 tour global
	var laves_a_supprimer = []
	for lave in laves_temporaires:
		lave["tours_restants"] -= 1
		print("🔥 Lave temporaire — ", lave["tours_restants"], " tour(s) global(aux) avant disparition")
		if lave["tours_restants"] <= 0:
			_restaurer_cases_lave(lave)
			laves_a_supprimer.append(lave)
	for l in laves_a_supprimer:
		laves_temporaires.erase(l)
		
	# Décompte et restauration des forêts temporaires (Pluie de Flèches)
	var forets_a_supprimer = []
	for foret in forets_temporaires:
		foret["tours_restants"] -= 1
		print("🌲 Forêt temporaire — ", foret["tours_restants"], " tour(s) avant disparition")
		if foret["tours_restants"] <= 0:
			_restaurer_cases_foret(foret)
			forets_a_supprimer.append(foret)
	for f in forets_a_supprimer:
		forets_temporaires.erase(f)

# -----------------------------------------------
# Applique l'effet de la case d'arrivée
# -----------------------------------------------
func _appliquer_effet_case(joueur: Node):
	var type = board.get_case(joueur.grid_x, joueur.grid_y)
	match type:
		board.CaseType.LAVE:
			joueur.recevoir_degats(10)
			print("🔥 Lave ! -10 HP")
		board.CaseType.EAU:
			joueur.hp_actuels = min(joueur.hp_actuels + 10, joueur.hp_max)
			print("💧 Eau ! +10 HP — HP : ", joueur.hp_actuels)
		board.CaseType.FORET:
			joueur.resistance_case = 0.10
			joueur.bonus_range_sorts = 0
			if joueur.has_method("entrer_foret"):
				joueur.entrer_foret()
			print("🌲 Forêt ! +10% résistance")
		board.CaseType.TOUR:
			joueur.bonus_range_sorts = 1
			joueur.resistance_case = 0.0
			print("🏰 Tour ! +1 Range sur les sorts")
		_:
			joueur.resistance_case = 0.0
			joueur.bonus_range_sorts = 0
			if joueur.has_method("quitter_foret"):
				joueur.quitter_foret()

# -----------------------------------------------
# Applique les effets persistants (Lave/Eau) en fin de tour
# -----------------------------------------------
func _appliquer_effets_persistants(joueur: Node):
	var type = board.get_case(joueur.grid_x, joueur.grid_y)
	match type:
		board.CaseType.LAVE:
			joueur.recevoir_degats(10)
			print("🔥 Dégâts de lave persistants ! -10 HP")
		board.CaseType.EAU:
			joueur.hp_actuels = min(joueur.hp_actuels + 10, joueur.hp_max)
			print("💧 Soin de l'eau persistant ! +10 HP")

# -----------------------------------------------
# Utilise un sort et retourne true si réussi
# -----------------------------------------------
func _utiliser_sort(joueur: Node, sort: Resource, cible_x: int, cible_y: int) -> bool:
	var cible = _get_joueur_en(cible_x, cible_y)
	
	match sort.id:
		"guerrier_mur":
			if _get_joueur_en(cible_x, cible_y) != null:
				print("Impossible de placer un Mur sur un joueur !")
				return false
			if board.get_case(cible_x, cible_y) == board.CaseType.TOUR:
				print("Impossible de placer un Mur sur une Tour !")
				return false
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			board.plateau[cible_x][cible_y] = board.CaseType.MUR
			print("🧱 Mur créé en (", cible_x, ",", cible_y, ")")
			renderer.queue_redraw()
			return true
		
		"guerrier_hache":
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			if cible:
				var degats = sort.degats + joueur.bonus_degats_sorts
				cible.recevoir_degats(degats)
				cible.ajouter_dot("hache_empoisonnee", 5, 3)
				joueur.gagner_gold_sur_degats(degats)
				print("🪓 Hache Empoisonnée ! ", degats, " dégâts + DoT")
			else:
				print("🪓 Hache lancée dans le vide...")
			return true
		
		"guerrier_bouclier":
			if not cible:
				print("Le Coup de Bouclier nécessite une cible !")
				return false
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			var degats = sort.degats + joueur.bonus_degats_sorts
			cible.recevoir_degats(degats)
			joueur.gagner_gold_sur_degats(degats)
			var bloque_par_mur = _repousser_joueur(joueur, cible, 2)
			if bloque_par_mur:
				cible.recevoir_degats(10)
				joueur.gagner_gold_sur_degats(10)
				print("💥 Impact contre le mur ! +10 dégâts")
			print("🛡️ Coup de Bouclier ! ", degats, " dégâts + repousse")
			return true
		
		"guerrier_rage":
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			joueur.activer_rage()
			return true
		
		"mage_boule_feu":
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			if cible:
				var degats = sort.degats + joueur.bonus_degats_sorts
				cible.recevoir_degats(degats)
				joueur.gagner_gold_sur_degats(degats)
				print("🔥 Boule de Feu ! ", degats, " dégâts")
			else:
				print("🔥 Boule de Feu dans le vide...")
			return true
		
		"mage_gel":
			if not cible:
				print("Le Gel nécessite une cible !")
				return false
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			cible.tours_immobilise = 2
			print("❄️ Gel ! ", cible.name, " immobilisé 2 tours")
			return true
		
		"mage_meteore":
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			meteores_en_attente.append({
				"cible_x": cible_x,
				"cible_y": cible_y,
				"tours_restants": 2,  # 2 tours GLOBAUX
				"lanceur": joueur
			})
			print("☄️ Météore lancé ! Impact dans 2 tours globaux en (", cible_x, ",", cible_y, ")")
			return true
		
		"mage_tempete":
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			for j in [joueur1, joueur2, joueur3]:
				if j == joueur or not j.est_place or j.est_mort:
					continue
				var degats = sort.degats + joueur.bonus_degats_sorts
				j.recevoir_degats(degats)
				j.attaque_portee = max(0, j.attaque_portee - 2)
				joueur.gagner_gold_sur_degats(degats)
				print("⚡ Tempête Arcanique ! ", degats, " dégâts sur ", j.name)
			return true
			# --- ARCHER ---
		"archer_fleche":
			if not cible:
				print("La Flèche nécessite une cible !")
				return false
			
			# On utilise les stats ACTUELLES du joueur — pas celles du sort
			# Ça inclut automatiquement les bonus du passif Archer en forêt
			# (+10 attaque, +1 portée si est_en_foret = true)
			var distance = abs(cible_x - joueur.grid_x) + abs(cible_y - joueur.grid_y)
			if distance > joueur.attaque_portee:
				print("Cible hors de portée de la Flèche !")
				return false
			
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			
			# --- Tir initial — dégâts = attaque_degats du joueur ---
			var degats = joueur.attaque_degats + joueur.bonus_degats_sorts
			cible.recevoir_degats(degats)
			joueur.gagner_gold_sur_degats(degats)
			joueur.a_attaque_ce_tour = true
			print("🏹 Flèche Rebondissante ! ", degats, " dégâts sur ", cible.name)
			
			# --- Rebond — moitié des dégâts de base du joueur ---
			var rebond_cible = _trouver_rebond(joueur, cible)
			if rebond_cible:
				if _a_ligne_de_vue(cible.grid_x, cible.grid_y, rebond_cible.grid_x, rebond_cible.grid_y):
					var degats_rebond = (joueur.attaque_degats / 2) + joueur.bonus_degats_sorts
					rebond_cible.recevoir_degats(degats_rebond)
					joueur.gagner_gold_sur_degats(degats_rebond)
					print("🏹 Rebond sur ", rebond_cible.name, " ! ", degats_rebond, " dégâts")
				else:
					print("🏹 Pas de ligne de vue pour le rebond — annulé")
			else:
				print("🏹 Aucune cible pour le rebond")
			return true

		"archer_piege":
			# Ne peut être posé que sur une case VIDE de joueurs
			if cible:
				print("Impossible de poser un piège sur un joueur !")
				return false
			var type_case = board.get_case(cible_x, cible_y)
			if type_case == board.CaseType.VIDE or type_case == board.CaseType.MUR or type_case == board.CaseType.TOUR:
				print("Impossible de poser un piège ici !")
				return false
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			# Enregistre le piège — invisible pour l'ennemi (pas de rendu spécial)
			pieges_actifs.append({
				"x": cible_x,
				"y": cible_y,
				"poseur": joueur
			})
			print("🪤 Piège posé en (", cible_x, ",", cible_y, ") — invisible !")
			return true

		"archer_tir_cible":
			# Nécessite une cible — ligne de vue gérée par le Game Design (pas implémentée pour l'instant)
			if not cible:
				print("Le Tir Ciblé nécessite une cible !")
				return false
			# Vérifie si la cible est sur une case Forêt → bonus dégâts + coût Gold
			var cible_sur_foret = board.get_case(cible.grid_x, cible.grid_y) == board.CaseType.FORET
			if cible_sur_foret:
				if joueur.gold < 5:
					print("Pas assez de Gold pour Tir Ciblé sur forêt ! (5 Gold requis)")
					return false
				joueur.gold -= 5  # Coût Gold uniquement si cible sur forêt
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			var degats = (60 if cible_sur_foret else 40) + joueur.bonus_degats_sorts
			cible.recevoir_degats(degats)
			joueur.gagner_gold_sur_degats(degats)
			if cible_sur_foret:
				print("🏹 Tir Ciblé (forêt) ! ", degats, " dégâts — 5 Gold dépensés")
			else:
				print("🏹 Tir Ciblé ! ", degats, " dégâts")
			return true

		"archer_pluie":
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			var cases_transformees = []
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var x = cible_x + dx
					var y = cible_y + dy
					if x < 0 or x >= 8 or y < 0 or y >= 8:
						continue
					# Dégâts sur tous les joueurs dans la zone (alliés compris)
					for j in [joueur1, joueur2, joueur3]:
						if j.est_place and not j.est_mort:
							if j.grid_x == x and j.grid_y == y:
								var degats = sort.degats + joueur.bonus_degats_sorts
								j.recevoir_degats(degats)
								joueur.gagner_gold_sur_degats(degats)
								print("🏹 Pluie de Flèches ! ", j.name, " touché — ", degats, " dégâts")
					# Cases touchées → Forêt (sauf TOUR et VIDE)
					var type_case = board.get_case(x, y)
					if type_case == board.CaseType.TOUR or type_case == board.CaseType.VIDE:
						continue
					# Mémorise le type original pour restauration
					cases_transformees.append({
						"x": x,
						"y": y,
						"type_original": type_case
					})
					board.plateau[x][y] = board.CaseType.FORET
			# Enregistre pour restauration dans 2 tours globaux
			# tours_restants = 3 pour éviter restauration immédiate (même logique que météore)
			forets_temporaires.append({
				"cases": cases_transformees,
				"tours_restants": 3
			})
			renderer.queue_redraw()
			print("🌲 Pluie de Flèches ! ", cases_transformees.size(), " case(s) → Forêt (2 tours globaux)")
			return true
	return false

# -----------------------------------------------
# Repousse un joueur de N cases
# Retourne true si bloqué par un mur/bord
# -----------------------------------------------
func _repousser_joueur(attaquant: Node, cible: Node, cases: int) -> bool:
	var dir_x = cible.grid_x - attaquant.grid_x
	var dir_y = cible.grid_y - attaquant.grid_y
	if dir_x != 0: dir_x = dir_x / abs(dir_x)
	if dir_y != 0: dir_y = dir_y / abs(dir_y)
	
	var nouveau_x = cible.grid_x
	var nouveau_y = cible.grid_y
	var bloque_par_mur = false
	
	for i in range(cases):
		var test_x = nouveau_x + dir_x
		var test_y = nouveau_y + dir_y
		if test_x < 0 or test_x >= 8 or test_y < 0 or test_y >= 8:
			break
		var type = board.get_case(test_x, test_y)
		if type == board.CaseType.MUR or type == board.CaseType.VIDE:
			bloque_par_mur = true
			break
		if board.case_occupee(test_x, test_y):
			break
		nouveau_x = test_x
		nouveau_y = test_y
	
	if nouveau_x != cible.grid_x or nouveau_y != cible.grid_y:
		board.liberer_case(cible.grid_x, cible.grid_y)
		cible.grid_x = nouveau_x
		cible.grid_y = nouveau_y
		board.occuper_case(nouveau_x, nouveau_y)
		print("💨 Repoussé en (", nouveau_x, ",", nouveau_y, ")")
	
	return bloque_par_mur

# -----------------------------------------------
# Fait exploser un Météore — zone 3x3
# Mémorise le type ORIGINAL de chaque case avant de la transformer en Lave
# -----------------------------------------------
func _exploser_meteore(meteore: Dictionary):
	var cx = meteore["cible_x"]
	var cy = meteore["cible_y"]
	var lanceur = meteore["lanceur"]
	print("☄️ IMPACT du Météore en (", cx, ",", cy, ") !")
	
	# On stocke les cases transformées avec leur type d'origine
	var cases_transformees = []
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var x = cx + dx
			var y = cy + dy
			if x < 0 or x >= 8 or y < 0 or y >= 8:
				continue
			
			# Dégâts sur les joueurs présents (alliés compris)
			for j in [joueur1, joueur2, joueur3]:
				if j.est_place and not j.est_mort:
					if j.grid_x == x and j.grid_y == y:
						var degats = 25 + lanceur.bonus_degats_sorts
						j.recevoir_degats(degats)
						lanceur.gagner_gold_sur_degats(degats)
						print("☄️ ", j.name, " touché — ", degats, " dégâts")
			
			# Les TOURS sont indestructibles
			if board.get_case(x, y) == board.CaseType.TOUR:
				continue
			
			# Mémorise le type original AVANT de poser la lave
			cases_transformees.append({
				"x": x,
				"y": y,
				"type_original": board.get_case(x, y)
			})
			board.plateau[x][y] = board.CaseType.LAVE
	
	# Enregistre pour restauration dans 1 tour GLOBAL
	laves_temporaires.append({
		"cases": cases_transformees,
		"tours_restants": 2
	})
	
	renderer.queue_redraw()
	print("🔥 ", cases_transformees.size(), " case(s) → Lave (disparaît dans 1 tour global)")

# -----------------------------------------------
# Restaure les cases de Lave créées par un Météore
# Remet chaque case à son type ORIGINAL (EAU, FORÊT, NORMAL...)
# -----------------------------------------------
func _restaurer_cases_lave(lave: Dictionary):
	print("✨ Restauration des cases de lave")
	for case_info in lave["cases"]:
		var x = case_info["x"]
		var y = case_info["y"]
		board.plateau[x][y] = case_info["type_original"]
		print("✨ (", x, ",", y, ") → restaurée")
		# Si un joueur est sur cette case, ré-applique l'effet
		var joueur_sur_case = _get_joueur_en(x, y)
		if joueur_sur_case:
			_appliquer_effet_case(joueur_sur_case)
	renderer.queue_redraw()
	
	# -----------------------------------------------
# Vérifie si un joueur atterrit sur un piège
# Appelée après chaque déplacement
# -----------------------------------------------
func _verifier_pieges(joueur: Node):
	var pieges_declenches = []
	for piege in pieges_actifs:
		# Le piège ne se déclenche que pour les ennemis du poseur
		if piege["x"] == joueur.grid_x and piege["y"] == joueur.grid_y:
			if piege["poseur"] != joueur:
				joueur.recevoir_degats(10)
				# Immobilise le joueur 1 tour
				joueur.tours_immobilise = 1
				pieges_declenches.append(piege)
				print("🪤 Piège déclenché ! 10 dégâts + immobilisé 1 tour")
	# Supprime les pièges déclenchés — ils ne servent qu'une fois
	for piege in pieges_declenches:
		pieges_actifs.erase(piege)

# -----------------------------------------------
# Restaure les cases de Forêt créées par la Pluie de Flèches
# Remet chaque case à son type ORIGINAL
# -----------------------------------------------
func _restaurer_cases_foret(foret: Dictionary):
	print("🍂 Restauration des Forêts temporaires")
	for case_info in foret["cases"]:
		var x = case_info["x"]
		var y = case_info["y"]
		board.plateau[x][y] = case_info["type_original"]
		print("🍂 (", x, ",", y, ") → restaurée")
		# Si un joueur est sur cette case, ré-applique l'effet
		var joueur_sur_case = _get_joueur_en(x, y)
		if joueur_sur_case:
			_appliquer_effet_case(joueur_sur_case)
	renderer.queue_redraw()


# -----------------------------------------------
# Trouve la cible du rebond de la Flèche Rebondissante
# Cherche l'ennemi le plus proche de la cible initiale
# Exclut le lanceur — la flèche ne rebondit pas sur lui
# -----------------------------------------------
func _trouver_rebond(lanceur: Node, cible_initiale: Node) -> Node:
	var meilleure_cible = null
	var meilleure_distance = 999
	
	for j in [joueur1, joueur2]:
		# Exclut la cible initiale, le lanceur, et les joueurs morts/non placés
		if j == cible_initiale or j == lanceur:
			continue
		if not j.est_place or j.est_mort:
			continue
		
		# Distance depuis la cible initiale (pas depuis le lanceur)
		var distance = abs(j.grid_x - cible_initiale.grid_x) + abs(j.grid_y - cible_initiale.grid_y)
		if distance < meilleure_distance:
			meilleure_distance = distance
			meilleure_cible = j
	
	return meilleure_cible

# -----------------------------------------------
# Vérifie la ligne de vue entre deux cases
# Utilise l'algorithme de Bresenham pour tracer le chemin
# Retourne false si un MUR ou VIDE bloque la trajectoire
# -----------------------------------------------
func _a_ligne_de_vue(x1: int, y1: int, x2: int, y2: int) -> bool:
	var dx = abs(x2 - x1)
	var dy = abs(y2 - y1)
	var sx = 1 if x1 < x2 else -1
	var sy = 1 if y1 < y2 else -1
	var err = dx - dy
	
	var x = x1
	var y = y1
	
	while true:
		# On ne vérifie pas les cases de départ et d'arrivée elles-mêmes
		if not (x == x1 and y == y1) and not (x == x2 and y == y2):
			var type = board.get_case(x, y)
			# MUR et VIDE bloquent la ligne de vue
			if type == board.CaseType.MUR or type == board.CaseType.VIDE:
				return false
		
		# Condition d'arrêt — on a atteint la case d'arrivée
		if x == x2 and y == y2:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	
	return true
# -----------------------------------------------
# Retourne le joueur en (x, y) ou null
# -----------------------------------------------
func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in [joueur1, joueur2, joueur3]:
		if joueur.est_place and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null

# -----------------------------------------------
# Appelée quand un joueur meurt
# -----------------------------------------------
func _on_joueur_mort(joueur: Node):
	board.liberer_case(joueur.grid_x, joueur.grid_y)
	renderer.queue_redraw()
