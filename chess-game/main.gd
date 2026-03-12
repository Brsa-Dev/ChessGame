extends Node2D

@onready var board = $Board
@onready var renderer = $Renderer
@onready var joueur1 = $Joueur1
@onready var joueur2 = $Joueur2
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

func _ready():
	renderer.board = board
	renderer.joueurs = [joueur1, joueur2]
	tour_manager.initialiser([joueur1, joueur2])
	renderer.joueur_actif = tour_manager.get_joueur_actif()
	bouton_fin_tour.pressed.connect(fin_de_tour)
	
	joueur1.mort.connect(_on_joueur_mort.bind(joueur1))
	joueur2.mort.connect(_on_joueur_mort.bind(joueur2))
	
	tour_manager.phase_boutique.connect(_on_phase_boutique)
	shop_ui.boutique_fermee.connect(_on_boutique_fermee)
	shop_ui.shop_manager = shop_manager
	
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
	if index_joueur_boutique < 2:
		shop_ui.ouvrir(joueur2)
	else:
		bouton_fin_tour.disabled = false
		print("=== Phase boutique terminée — La partie reprend ===")

# -----------------------------------------------
# Gestion des inputs
# -----------------------------------------------
func _input(event):
	# -----------------------------------------------
	# Touches clavier — sélection des sorts (A/Z/E/R)
	# Uniquement si le joueur est sélectionné
	# -----------------------------------------------
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
			
			# Sélectionne ou désélectionne le sort
			if sort_selectionne == index:
				sort_selectionne = -1
				print("Sort désélectionné")
			else:
				sort_selectionne = index
				print("Sort sélectionné : ", sort.nom, " — Portée : ", sort.portee)
			
			renderer.sort_selectionne = sort_selectionne
			renderer.queue_redraw()
		return

	# -----------------------------------------------
	# Clics souris
	# -----------------------------------------------
	if event is InputEventMouseButton and event.pressed:
		var cell = renderer.screen_to_grid(event.position)
		var joueur_actif = tour_manager.get_joueur_actif()

		# Clic hors plateau → désélection
		if cell.x < 0 or cell.x >= 8 or cell.y < 0 or cell.y >= 8:
			if joueur_selectionne:
				joueur_selectionne = false
				sort_selectionne = -1
				renderer.joueur_selectionne = false
				renderer.sort_selectionne = -1
				renderer.queue_redraw()
			return

		# Cas 1 — joueur pas encore placé
		if not joueur_actif.est_place:
			if not board.case_occupee(cell.x, cell.y):
				board.occuper_case(cell.x, cell.y)
				joueur_actif.placer(cell.x, cell.y)
				print("Joueur placé en (", cell.x, ", ", cell.y, ")")
			else:
				print("Case déjà occupée !")

		# Cas 2 — joueur placé, pas encore sélectionné
		elif not joueur_selectionne:
			if cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				if joueur_actif.peut_se_deplacer() or not joueur_actif.a_attaque_ce_tour:
					joueur_selectionne = true
					print("Joueur sélectionné — PM : ", joueur_actif.pm_actuels)
				else:
					print("Plus de PM et déjà attaqué !")

		# Cas 3 — joueur sélectionné
		else:
			# --- Sort sélectionné → clic = cibler ---
			if sort_selectionne >= 0:
				var sort = joueur_actif.sorts[sort_selectionne]
				var portee_effective = sort.portee + joueur_actif.bonus_range_sorts
				var distance = abs(cell.x - joueur_actif.grid_x) + abs(cell.y - joueur_actif.grid_y)
				
				# Tempête Arcanique : portée illimitée (portee = 0)
				var a_portee = (sort.portee == 0) or (distance <= portee_effective)
				
				if a_portee:
					var sort_utilise = _utiliser_sort(joueur_actif, sort, cell.x, cell.y)
					if sort_utilise:
						sort_selectionne = -1
						renderer.sort_selectionne = -1
						joueur_selectionne = false
					# Sinon on garde le focus pour réessayer
				else:
					print("Cible hors de portée du sort !")
				
				renderer.queue_redraw()
				return

			# Reclique sur soi-même → désélection
			elif cell.x == joueur_actif.grid_x and cell.y == joueur_actif.grid_y:
				joueur_selectionne = false
				print("Joueur désélectionné")

			# Clic sur un ennemi → attaque normale
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

			# Clic sur une case libre → déplacement
			elif joueur_actif.peut_se_deplacer_vers(cell.x, cell.y):
				var type_case = board.get_case(cell.x, cell.y)
				if type_case == board.CaseType.VIDE or type_case == board.CaseType.MUR:
					print("Case infranchissable !")
				elif not board.case_occupee(cell.x, cell.y):
					board.liberer_case(joueur_actif.grid_x, joueur_actif.grid_y)
					var type_arrivee = board.get_case(cell.x, cell.y)
					var cout = 2 if type_arrivee == board.CaseType.FORET else -1
					joueur_actif.deplacer(cell.x, cell.y, cout)
					
					# Passif Fripon — note le déplacement
					if joueur_actif.get("s_est_deplace_ce_tour") != null:
						joueur_actif.s_est_deplace_ce_tour = true
					
					_appliquer_effet_case(joueur_actif)
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
# Fin de tour — effets persistants + météores
# -----------------------------------------------
func fin_de_tour():
	joueur_selectionne = false
	sort_selectionne = -1
	renderer.sort_selectionne = -1
	
	# Effets persistants sur le joueur qui finit son tour
	var joueur_qui_finit = tour_manager.get_joueur_actif()
	if joueur_qui_finit.est_place:
		_appliquer_effets_persistants(joueur_qui_finit)
	
	# Réduit le délai des météores et les fait exploser si prêts
	var a_supprimer = []
	for meteore in meteores_en_attente:
		meteore["tours_restants"] -= 1
		print("☄️ Météore en route — ", meteore["tours_restants"], " tour(s) restants")
		if meteore["tours_restants"] <= 0:
			_exploser_meteore(meteore)
			a_supprimer.append(meteore)
	for m in a_supprimer:
		meteores_en_attente.erase(m)
	
	tour_manager.passer_au_tour_suivant()
	var joueur_actif = tour_manager.get_joueur_actif()
	print("--- Tour du Joueur ", tour_manager.index_joueur_actif + 1, " ---")
	renderer.joueur_actif = joueur_actif
	renderer.joueur_selectionne = false
	renderer.queue_redraw()

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
# Applique les effets persistants (Lave/Eau)
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
		# --- GUERRIER ---
		"guerrier_mur":
			if _get_joueur_en(cible_x, cible_y) != null:
				print("Impossible de placer un Mur sur un joueur !")
				return false
			if board.get_case(cible_x, cible_y) == board.CaseType.TOUR:
				print("Impossible de placer un Mur sur une Tour !")
				return false
			joueur.gold -= sort.cout_gold
			sort.declencher_cooldown()
			board.plateau[cible_x][cible_y] = board.CaseType.MUR
			print("🧱 Mur créé en (", cible_x, ",", cible_y, ")")
			renderer.queue_redraw()
			return true
		
		"guerrier_hache":
			# Pénalise le misclick — sort utilisé même sans cible
			joueur.gold -= sort.cout_gold
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
			joueur.gold -= sort.cout_gold
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
			joueur.gold -= sort.cout_gold
			sort.declencher_cooldown()
			joueur.activer_rage()
			return true
		
		# --- MAGE ---
		"mage_boule_feu":
			# Pénalise le misclick — sort utilisé même sans cible
			joueur.gold -= sort.cout_gold
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
			# Nécessite une cible — on garde le focus sinon
			if not cible:
				print("Le Gel nécessite une cible !")
				return false
			joueur.gold -= sort.cout_gold
			sort.declencher_cooldown()
			cible.tours_immobilise = 2
			print("❄️ Gel ! ", cible.name, " immobilisé 2 tours")
			return true
		
		"mage_meteore":
			# Enregistre le météore — explose dans 2 tours
			joueur.gold -= sort.cout_gold
			sort.declencher_cooldown()
			meteores_en_attente.append({
				"cible_x": cible_x,
				"cible_y": cible_y,
				"tours_restants": 2,
				"lanceur": joueur
			})
			print("☄️ Météore en route ! Impact dans 2 tours en (", cible_x, ",", cible_y, ")")
			return true
		
		"mage_tempete":
			# Frappe tous les ennemis sur le plateau
			joueur.gold -= sort.cout_gold
			sort.declencher_cooldown()
			for j in [joueur1, joueur2]:
				if j == joueur or not j.est_place or j.est_mort:
					continue
				var degats = sort.degats + joueur.bonus_degats_sorts
				j.recevoir_degats(degats)
				# -2 Range pendant 1 tour
				j.attaque_portee = max(0, j.attaque_portee - 2)
				joueur.gagner_gold_sur_degats(degats)
				print("⚡ Tempête Arcanique ! ", degats, " dégâts sur ", j.name)
			return true
	
	return false

# -----------------------------------------------
# Repousse un joueur de N cases
# Retourne true si bloqué par un mur
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
# Fait exploser un Météore — zone 3x3, cases → Lave
# -----------------------------------------------
func _exploser_meteore(meteore: Dictionary):
	var cx = meteore["cible_x"]
	var cy = meteore["cible_y"]
	var lanceur = meteore["lanceur"]
	print("☄️ IMPACT du Météore en (", cx, ",", cy, ") !")
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var x = cx + dx
			var y = cy + dy
			if x < 0 or x >= 8 or y < 0 or y >= 8:
				continue
			# Dégâts sur tous les joueurs dans la zone (alliés compris)
			for j in [joueur1, joueur2]:
				if j.est_place and not j.est_mort:
					if j.grid_x == x and j.grid_y == y:
						var degats = 25 + lanceur.bonus_degats_sorts
						j.recevoir_degats(degats)
						lanceur.gagner_gold_sur_degats(degats)
						print("☄️ ", j.name, " touché — ", degats, " dégâts")
			# Cases touchées → Lave (sauf TOUR)
			if board.get_case(x, y) != board.CaseType.TOUR:
				board.plateau[x][y] = board.CaseType.LAVE
	
	renderer.queue_redraw()

# -----------------------------------------------
# Retourne le joueur en (x, y) ou null
# -----------------------------------------------
func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in [joueur1, joueur2]:
		if joueur.est_place and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null

# -----------------------------------------------
# Appelée quand un joueur meurt
# -----------------------------------------------
func _on_joueur_mort(joueur: Node):
	board.liberer_case(joueur.grid_x, joueur.grid_y)
	renderer.queue_redraw()
