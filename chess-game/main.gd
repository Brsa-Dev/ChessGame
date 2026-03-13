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
@onready var log_ui = $UI/LogUI
@onready var hud_ui = $HudUI
@onready var event_manager = $EventManager

var joueur_selectionne: bool = false
var sort_selectionne: int = -1
var index_joueur_boutique: int = 0

var meteores_en_attente: Array = []
var laves_temporaires: Array = []
var pieges_actifs: Array = []
var forets_temporaires: Array = []

# -----------------------------------------------
func _ready():
	# --- Plateau ---
	renderer.board = board

	# --- HUD : on donne le board AVANT d'initialiser ---
	# Le rafraichir() sera appelé APRÈS tour_manager.initialiser()
	hud_ui.board = board

	# EventManager — doit connaître le board pour trouver les cases libres
	event_manager.board = board

	# Donne la référence au renderer pour le dessin
	renderer.event_manager = event_manager
	
	# Connecte les signaux de l'event manager
	event_manager.evenement_declenche.connect(_on_evenement_declenche)
	event_manager.piece_ramassee.connect(_on_piece_ramassee)
	event_manager.coffre_ramasse.connect(_on_coffre_ramasse)
	
	# --- Renderer ---
	renderer.joueurs = [joueur1, joueur2, joueur3]

	# --- Tour Manager — DOIT être avant tout appel à get_joueur_actif() ---
	tour_manager.initialiser([joueur1, joueur2, joueur3])

	# --- Renderer : joueur actif connu maintenant ---
	renderer.joueur_actif = tour_manager.get_joueur_actif()

	# --- Signaux ---
	bouton_fin_tour.pressed.connect(fin_de_tour)
	joueur1.mort.connect(_on_joueur_mort.bind(joueur1))
	joueur2.mort.connect(_on_joueur_mort.bind(joueur2))
	joueur3.mort.connect(_on_joueur_mort.bind(joueur3))
	tour_manager.phase_boutique.connect(_on_phase_boutique)
	shop_ui.boutique_fermee.connect(_on_boutique_fermee)
	shop_ui.shop_manager = shop_manager
	tour_manager.tour_global_termine.connect(_on_tour_global_termine)

	# --- HUD : maintenant que tout est initialisé, on peut rafraîchir ---
	hud_ui.rafraichir([joueur1, joueur2, joueur3], tour_manager.get_joueur_actif())

	var taille_ecran = get_viewport().get_visible_rect().size
	bouton_fin_tour.set_position(Vector2(
		(taille_ecran.x / 2) - 55,  # Centré sur l'écran
		taille_ecran.y - 45          # Collé en bas
	))

	renderer.queue_redraw()
	print("Main prêt !")

# -----------------------------------------------
# _log — raccourci pour envoyer un message au LogUI
# Détermine automatiquement la couleur selon le joueur
# joueur = null → message système (blanc)
# -----------------------------------------------
func _log(message: String, joueur: Node = null):
	var couleur = log_ui.COULEUR_SYSTEME
	if joueur == joueur1:
		couleur = log_ui.COULEUR_J1
	elif joueur == joueur2:
		couleur = log_ui.COULEUR_J2
	elif joueur == joueur3:
		couleur = log_ui.COULEUR_J3
	log_ui.ajouter(message, couleur)

# -----------------------------------------------
# _rafraichir_hud — Raccourci pour mettre à jour
# le HUD après chaque action. Toujours appeler
# cette fonction plutôt que hud_ui.rafraichir()
# directement pour ne pas oublier les paramètres.
# -----------------------------------------------
func _rafraichir_hud():
	hud_ui.rafraichir([joueur1, joueur2, joueur3], tour_manager.get_joueur_actif())
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

			# -----------------------------------------------
			# CAS SPÉCIAL : Dérobade avec marque active
			# → Explosion IMMÉDIATE à la pression de la touche
			# → 0 PM, pas de vérification CD
			# -----------------------------------------------
			if sort.id == "fripon_derobade" and joueur_actif.get("marque_cible") != null:
				_exploser_marque_derobade(joueur_actif)
				sort_selectionne = -1
				renderer.sort_selectionne = -1
				renderer.queue_redraw()
				return

			# Vérification CD — uniquement pour la POSE
			if not sort.est_disponible():
				print("Sort en recharge ! (", sort.cooldown_actuel, " tours restants)")
				return

			if joueur_actif.gold < sort.cout_gold:
				print("Pas assez de Gold pour ce sort !")
				return

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
				_log("📍 " + joueur_actif.name + " placé en (" + str(cell.x) + "," + str(cell.y) + ")", joueur_actif)
				_rafraichir_hud()
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
				
				# -----------------------------------------------
				# CORRECTION : portée effective de la Flèche Rebondissante
				# La Flèche utilise joueur.attaque_portee (3 base, 4 en forêt)
				# et non sort.portee + bonus_range_sorts
				# Aligné avec renderer.gd et _utiliser_sort
				# -----------------------------------------------
				var portee_effective: int
				if sort.id == "archer_fleche":
					portee_effective = joueur_actif.attaque_portee  # 3 ou 4 selon passif forêt
				else:
					portee_effective = sort.portee + joueur_actif.bonus_range_sorts

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
					_log("⚔️ " + joueur_actif.name + " attaque " + cible.name + " — " + str(joueur_actif.attaque_degats) + " dmg", joueur_actif)
					_rafraichir_hud()
					joueur_selectionne = false
				else:
					if joueur_actif.a_attaque_ce_tour:
						print("Déjà attaqué ce tour !")
					elif joueur_actif.pm_actuels < joueur_actif.attaque_cout_pm:
						print("Pas assez de PM !")
					else:
						print("Cible hors de portée !")

			elif event_manager.get_mine_en(cell.x, cell.y) != {}:
				if joueur_actif.peut_attaquer(cell.x, cell.y):
					joueur_actif.pm_actuels -= joueur_actif.attaque_cout_pm
					joueur_actif.a_attaque_ce_tour = true
					joueur_actif.gagner_gold_sur_degats(joueur_actif.attaque_degats)
					event_manager.attaquer_mine(cell.x, cell.y, joueur_actif.attaque_degats, joueur_actif)
					_log("⛏️ " + joueur_actif.name + " attaque une Mine — " + str(joueur_actif.attaque_degats) + " dmg", joueur_actif)
					_rafraichir_hud()
					joueur_selectionne = false
					renderer.queue_redraw()
				else:
					print("Mine hors de portée ou déjà attaqué !")

			elif joueur_actif.peut_se_deplacer_vers(cell.x, cell.y):
				var type_case = board.get_case(cell.x, cell.y)
				if type_case == board.CaseType.VIDE or type_case == board.CaseType.MUR:
					print("Case infranchissable !")
				elif not board.case_occupee(cell.x, cell.y):
					board.liberer_case(joueur_actif.grid_x, joueur_actif.grid_y)
					var type_arrivee = board.get_case(cell.x, cell.y)
					var cout = 2 if type_arrivee == board.CaseType.FORET else -1
					joueur_actif.deplacer(cell.x, cell.y, cout)
					# Passif Fripon : le déplacement reset a_attaque_ce_tour
					# → le Fripon peut réattaquer après s'être déplacé
					if joueur_actif.has_method("attaquer") and joueur_actif.get_script() != null:
						if joueur_actif.get("ruee_disponible") != null:  # C'est un Fripon
							joueur_actif.a_attaque_ce_tour = false
					if joueur_actif.get("s_est_deplace_ce_tour") != null:
						joueur_actif.s_est_deplace_ce_tour = true
					_appliquer_effet_case(joueur_actif)
					_verifier_pieges(joueur_actif)
					event_manager.verifier_ramassage(joueur_actif)
					board.occuper_case(joueur_actif.grid_x, joueur_actif.grid_y)
					joueur_selectionne = false
					_log("🚶 " + joueur_actif.name + " → (" + str(cell.x) + "," + str(cell.y) + ") — PM : " + str(joueur_actif.pm_actuels), joueur_actif)
					_rafraichir_hud()
				else:
					print("Case occupée !")
			else:
				print("Case inaccessible !")

		renderer.joueur_actif = joueur_actif
		renderer.joueur_selectionne = joueur_selectionne
		renderer.queue_redraw()

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

	# ❌ SUPPRIMÉ — plus d'explosion automatique au début du tour
	# L'explosion est TOUJOURS manuelle (touche Z)

	# Décrémente la marque du joueur qui VIENT DE JOUER
	# (pas le nouveau joueur actif)
	if joueur_qui_finit.get("marque_cible") != null:
		joueur_qui_finit.marque_tours_restants -= 1
		print("🎯 Marque — ", joueur_qui_finit.marque_tours_restants, " tour(s) avant expiration")
		if joueur_qui_finit.marque_tours_restants <= 0:
			joueur_qui_finit.marque_cible = null
			print("🎯 Marque expirée sans dégâts")

	_log("--- Tour de " + joueur_actif.name + " ---")
	renderer.joueur_actif = joueur_actif
	renderer.joueur_selectionne = false
	renderer.queue_redraw()
	_rafraichir_hud()

# -----------------------------------------------
func _on_tour_global_termine(_numero_tour: int):
	
	event_manager.verifier_tour(_numero_tour)
	
	var cases_restaurees = event_manager.reduire_inondations()
	if cases_restaurees.size() > 0:
		# Ré-applique l'effet de case aux joueurs sur les cases restaurées
		for case_info in cases_restaurees:
			var j = _get_joueur_en(case_info["x"], case_info["y"])
			if j:
				_appliquer_effet_case(j)
		_log("🍂 === Les cases inondées sont restaurées ===")
		
	renderer.queue_redraw()
	
	print("=== Fin du tour global ", _numero_tour, " — Traitement météores/laves ===")
	var meteores_a_supprimer = []
	for meteore in meteores_en_attente:
		meteore["tours_restants"] -= 1
		print("☄️ Météore — ", meteore["tours_restants"], " tour(s) avant impact")
		if meteore["tours_restants"] <= 0:
			_exploser_meteore(meteore)
			meteores_a_supprimer.append(meteore)
	for m in meteores_a_supprimer:
		meteores_en_attente.erase(m)
	var laves_a_supprimer = []
	for lave in laves_temporaires:
		lave["tours_restants"] -= 1
		print("🔥 Lave — ", lave["tours_restants"], " tour(s) avant disparition")
		if lave["tours_restants"] <= 0:
			_restaurer_cases_lave(lave)
			laves_a_supprimer.append(lave)
	for l in laves_a_supprimer:
		laves_temporaires.erase(l)
	var forets_a_supprimer = []
	for foret in forets_temporaires:
		foret["tours_restants"] -= 1
		print("🌲 Forêt temp — ", foret["tours_restants"], " tour(s) avant disparition")
		if foret["tours_restants"] <= 0:
			_restaurer_cases_foret(foret)
			forets_a_supprimer.append(foret)
	for f in forets_a_supprimer:
		forets_temporaires.erase(f)

# -----------------------------------------------
func _appliquer_effet_case(joueur: Node):
	var type = board.get_case(joueur.grid_x, joueur.grid_y)
	match type:
		board.CaseType.LAVE:
			joueur.recevoir_degats(10)
			print("🔥 Lave ! -10 HP")
		board.CaseType.EAU:
			joueur.hp_actuels = min(joueur.hp_actuels + 10, joueur.hp_max)
			print("💧 Eau ! +10 HP")
		board.CaseType.FORET:
			joueur.resistance_case = 0.10
			joueur.bonus_range_sorts = 0
			if joueur.has_method("entrer_foret"):
				joueur.entrer_foret()
			print("🌲 Forêt ! +10% résistance")
		board.CaseType.TOUR:
			joueur.bonus_range_sorts = 1
			joueur.resistance_case = 0.0
			print("🏰 Tour ! +1 Range sorts")
		_:
			joueur.resistance_case = 0.0
			joueur.bonus_range_sorts = 0
			if joueur.has_method("quitter_foret"):
				joueur.quitter_foret()

func _appliquer_effets_persistants(joueur: Node):
	var type = board.get_case(joueur.grid_x, joueur.grid_y)
	match type:
		board.CaseType.LAVE:
			joueur.recevoir_degats(10)
			print("🔥 Lave persistante ! -10 HP")
		board.CaseType.EAU:
			joueur.hp_actuels = min(joueur.hp_actuels + 10, joueur.hp_max)
			print("💧 Eau persistante ! +10 HP")

# -----------------------------------------------
# Utilise un sort — retourne true si réussi
# -----------------------------------------------
func _utiliser_sort(joueur: Node, sort: Resource, cible_x: int, cible_y: int) -> bool:
	var cible = _get_joueur_en(cible_x, cible_y)
	
	# -----------------------------------------------
	# DÉTECTION MINE — Si la cible est une mine
	# et que le sort inflige des dégâts directs,
	# on redirige les dégâts sur la mine.
	# Les sorts utilitaires (Gel, Mur...) sont exclus.
	# -----------------------------------------------
	var mine = event_manager.get_mine_en(cible_x, cible_y)
	if mine != {} and cible == null:
		# Sorts qui ne font pas de sens sur une mine → bloqués
		var sorts_inapplicables = [
			"guerrier_mur", "guerrier_rage",
			"mage_gel", "mage_tempete",
			"archer_piege",
			"fripon_derobade", "fripon_lame", "fripon_frenesie"
		]
		if sort.id in sorts_inapplicables:
			print("Ce sort ne peut pas cibler une mine !")
			return false
		
		# Vérifie portée et PM
		var portee_effective = sort.portee + joueur.bonus_range_sorts
		var distance = abs(cible_x - joueur.grid_x) + abs(cible_y - joueur.grid_y)
		if distance > portee_effective and sort.portee != 0:
			print("Mine hors de portée du sort !")
			return false
		if joueur.pm_actuels < sort.cout_pm:
			print("Pas assez de PM !")
			return false
		if joueur.gold < sort.cout_gold:
			print("Pas assez de Gold !")
			return false
		
		# Consomme les ressources et déclenche le CD
		joueur.pm_actuels  -= sort.cout_pm
		joueur.gold        -= sort.cout_gold
		sort.declencher_cooldown()
		
		# Calcule les dégâts (avec bonus mage si applicable)
		var degats = sort.degats + joueur.bonus_degats_sorts
		joueur.gagner_gold_sur_degats(degats)
		event_manager.attaquer_mine(cible_x, cible_y, degats, joueur)
		
		_log("⛏️ " + joueur.name + " — " + sort.nom + " : " + str(degats) + " dmg sur une Mine", joueur)
		_rafraichir_hud()
		renderer.queue_redraw()
		return true
	
	match sort.id:
		
		# -----------------------------------------------
		# SORT GUERRIER
		# -----------------------------------------------
		"guerrier_mur":
			if _get_joueur_en(cible_x, cible_y) != null:
				print("Impossible — joueur sur la case !")
				return false
			if board.get_case(cible_x, cible_y) == board.CaseType.TOUR:
				print("Impossible — case Tour !")
				return false
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			board.plateau[cible_x][cible_y] = board.CaseType.MUR
			print("🧱 Mur créé en (", cible_x, ",", cible_y, ")")
			renderer.queue_redraw()
			_log("🧱 " + joueur.name + " crée un Mur en (" + str(cible_x) + "," + str(cible_y) + ")", joueur)
			_rafraichir_hud()
			return true
		"guerrier_hache":
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			if cible:
				var degats = sort.degats + joueur.bonus_degats_sorts
				cible.recevoir_degats(degats)
				cible.ajouter_dot("hache_empoisonnee", 5, 3)
				joueur.gagner_gold_sur_degats(degats)
				print("🪓 Hache Empoisonnée ! ", degats, " dmg + DoT")
				_log("🪓 " + joueur.name + " — Hache : " + str(degats) + " dmg + DoT sur " + cible.name, joueur)
			_rafraichir_hud()
			return true
		"guerrier_bouclier":
			if not cible:
				return false
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			var degats = sort.degats + joueur.bonus_degats_sorts
			cible.recevoir_degats(degats)
			joueur.gagner_gold_sur_degats(degats)
			var bloque = _repousser_joueur(joueur, cible, 2)
			# Log TOUJOURS — avec ou sans impact mur
			_log("🛡️ " + joueur.name + " — Bouclier : " + str(degats) + " dmg + repousse " + cible.name, joueur)
			if bloque:
				cible.recevoir_degats(10)
				joueur.gagner_gold_sur_degats(10)
				print("💥 Impact mur ! +10 dmg")
				_log("💥 Impact mur sur " + cible.name + " ! +10 dmg", joueur)
			_rafraichir_hud()
			return true  # ← ce return manquait aussi !
		"guerrier_rage":
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			joueur.activer_rage()
			_log("⚔️ " + joueur.name + " — Rage Berserker ! x2 attaque, +2 PM", joueur)
			_rafraichir_hud()
			return true
		# -----------------------------------------------
		# SORT MAGE
		# -----------------------------------------------
		"mage_boule_feu":
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			if cible:
				var degats = sort.degats + joueur.bonus_degats_sorts
				cible.recevoir_degats(degats)
				joueur.gagner_gold_sur_degats(degats)
				print("🔥 Boule de Feu ! ", degats, " dmg")
				_log("🔥 " + joueur.name + " — Boule de Feu : " + str(degats) + " dmg sur " + cible.name, joueur)
				_rafraichir_hud()
			return true
		"mage_gel":
			if not cible:
				return false
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			cible.tours_immobilise = 2
			print("❄️ Gel ! ", cible.name, " immobilisé 2 tours")
			_log("❄️ " + joueur.name + " — Gel : " + cible.name + " immobilisé 2 tours", joueur)
			_rafraichir_hud()
			return true
		"mage_meteore":
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			meteores_en_attente.append({
				"cible_x": cible_x, "cible_y": cible_y,
				"tours_restants": 2, "lanceur": joueur
			})
			print("☄️ Météore ! Impact dans 2 tours en (", cible_x, ",", cible_y, ")")
			_log("☄️ " + joueur.name + " — Météore en route ! Impact dans 2 tours", joueur)
			_rafraichir_hud()
			return true
		"mage_tempete":
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			for j in [joueur1, joueur2, joueur3]:
				if j == joueur or not j.est_place or j.est_mort:
					continue
				var degats = sort.degats + joueur.bonus_degats_sorts
				j.recevoir_degats(degats)
				j.attaque_portee = max(0, j.attaque_portee - 2)
				joueur.gagner_gold_sur_degats(degats)
				print("⚡ Tempête ! ", degats, " dmg sur ", j.name)
			_log("⚡ " + joueur.name + " — Tempête Arcanique sur tous les ennemis !", joueur)
			_rafraichir_hud()
			return true
		# -----------------------------------------------
		# SORT ARCHER
		# -----------------------------------------------
		"archer_fleche":
			if not cible:
				print("La Flèche nécessite une cible !")
				return false
			# Portée vérifiée avec attaque_portee (3 base, 4 forêt)
			var distance = abs(cible_x - joueur.grid_x) + abs(cible_y - joueur.grid_y)
			if distance > joueur.attaque_portee:
				print("Cible hors de portée de la Flèche !")
				return false
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			# Tir initial — dégâts depuis attaque_degats (20 base, 30 forêt)
			var degats = joueur.attaque_degats + joueur.bonus_degats_sorts
			cible.recevoir_degats(degats)
			joueur.gagner_gold_sur_degats(degats)
			joueur.a_attaque_ce_tour = true
			print("🏹 Flèche Rebondissante ! ", degats, " dmg sur ", cible.name)
			
			# Rebond — cherche ennemi dans rayon 2 cases autour de la CIBLE INITIALE
			var rebond_cible = _trouver_rebond(joueur, cible)
			if rebond_cible:
				# Ligne de vue : entre CIBLE INITIALE et CIBLE DU REBOND
				if _a_ligne_de_vue(cible.grid_x, cible.grid_y, rebond_cible.grid_x, rebond_cible.grid_y):
					var degats_rebond = (joueur.attaque_degats / 2) + joueur.bonus_degats_sorts
					rebond_cible.recevoir_degats(degats_rebond)
					joueur.gagner_gold_sur_degats(degats_rebond)
					print("🏹 Rebond sur ", rebond_cible.name, " ! ", degats_rebond, " dmg")
					# ← AJOUTE ICI
					_log("🏹 Rebond sur " + rebond_cible.name + " — " + str(degats_rebond) + " dmg", joueur)
				else:
					print("🏹 Rebond annulé — pas de ligne de vue")
			else:
				print("🏹 Aucun ennemi à ≤2 cases — pas de rebond")
			_log("🏹 " + joueur.name + " — Flèche : " + str(degats) + " dmg sur " + cible.name, joueur)
			_rafraichir_hud()
			return true
		"archer_piege":
			if cible:
				print("Impossible de poser un piège sur un joueur !")
				return false
			var type_case = board.get_case(cible_x, cible_y)
			if type_case == board.CaseType.VIDE or type_case == board.CaseType.MUR or type_case == board.CaseType.TOUR:
				print("Impossible de poser un piège ici !")
				return false
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			pieges_actifs.append({"x": cible_x, "y": cible_y, "poseur": joueur})
			print("🪤 Piège posé en (", cible_x, ",", cible_y, ") — invisible !")
			_log("🪤 " + joueur.name + " pose un Piège en (" + str(cible_x) + "," + str(cible_y) + ")", joueur)
			_rafraichir_hud()
			return true
		"archer_tir_cible":
			if not cible:
				return false
			var cible_sur_foret = board.get_case(cible.grid_x, cible.grid_y) == board.CaseType.FORET
			if cible_sur_foret and joueur.gold < 5:
				print("Pas assez de Gold ! (5 requis pour cible en forêt)")
				return false
			if cible_sur_foret:
				joueur.gold -= 5
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			var degats = (60 if cible_sur_foret else 40) + joueur.bonus_degats_sorts
			cible.recevoir_degats(degats)
			joueur.gagner_gold_sur_degats(degats)
			print("🏹 Tir Ciblé", " (forêt)" if cible_sur_foret else "", " ! ", degats, " dmg")
			_log("🏹 " + joueur.name + " — Tir Ciblé : " + str(degats) + " dmg sur " + cible.name, joueur)
			_rafraichir_hud()
			return true
		"archer_pluie":
			joueur.gold -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			var cases_transformees = []
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var x = cible_x + dx
					var y = cible_y + dy
					if x < 0 or x >= 8 or y < 0 or y >= 8:
						continue
					for j in [joueur1, joueur2, joueur3]:
						if j.est_place and not j.est_mort and j.grid_x == x and j.grid_y == y:
							var degats = sort.degats + joueur.bonus_degats_sorts
							j.recevoir_degats(degats)
							joueur.gagner_gold_sur_degats(degats)
							print("🏹 Pluie ! ", j.name, " — ", degats, " dmg")
					var type_case = board.get_case(x, y)
					if type_case == board.CaseType.TOUR or type_case == board.CaseType.VIDE:
						continue
					cases_transformees.append({"x": x, "y": y, "type_original": type_case})
					board.plateau[x][y] = board.CaseType.FORET
			forets_temporaires.append({"cases": cases_transformees, "tours_restants": 3})
			renderer.queue_redraw()
			print("🌲 Pluie de Flèches ! ", cases_transformees.size(), " case(s) → Forêt")
			_log("🏹 " + joueur.name + " — Pluie de Flèches en (" + str(cible_x) + "," + str(cible_y) + ")", joueur)
			_rafraichir_hud()
			return true
		# -----------------------------------------------
		# SORT FRIPON
		# -----------------------------------------------
		"fripon_ruee":
			if not joueur.ruee_disponible:
				print("Ruée non disponible !")
				return false
			if joueur.gold < sort.cout_gold:
				print("Pas assez de Gold !")
				return false

			# Si cible ennemie → repositionnement autour + 5 dmg
			# Si case libre (cible == null) → téléport DIRECT sur la case cliquée
			var case_arrivee: Vector2i
			if cible:
				case_arrivee = _trouver_case_libre_pres(cible_x, cible_y, joueur)
				if case_arrivee == Vector2i(-1, -1):
					print("Aucune case libre autour de la cible !")
					return false
				var degats = sort.degats + joueur.bonus_degats_sorts
				cible.recevoir_degats(degats)
				joueur.gagner_gold_sur_degats(degats)
				print("🗡️ Ruée ! ", degats, " dmg sur ", cible.name)
			else:
				# Case libre — on y va directement
				case_arrivee = Vector2i(cible_x, cible_y)

			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			joueur.ruee_disponible      = false
			joueur.attaques_depuis_ruee = 0

			board.liberer_case(joueur.grid_x, joueur.grid_y)
			joueur.grid_x = case_arrivee.x
			joueur.grid_y = case_arrivee.y
			board.occuper_case(joueur.grid_x, joueur.grid_y)

			# La Ruée compte comme un déplacement → reset a_attaque_ce_tour
			# Le Fripon peut donc réattaquer après une Ruée, comme après un déplacement classique
			joueur.a_attaque_ce_tour = false

			_appliquer_effet_case(joueur)
			print("🗡️ Ruée — repositionné en (", case_arrivee.x, ",", case_arrivee.y, ")")
			renderer.queue_redraw()
			_log("🗡️ " + joueur.name + " — Ruée vers (" + str(case_arrivee.x) + "," + str(case_arrivee.y) + ")", joueur)
			_rafraichir_hud()
			return true
		"fripon_derobade":
			# -----------------------------------------------
			# SORT DOUBLE : Dérobade / Explosion
			# -----------------------------------------------

			# === CAS EXPLOSION ===
			# La marque est déjà active — on explose sur la cible marquée.
			# Ce cas est géré directement dans _input() (touche immédiate).
			# Ce bloc est ici en fallback de sécurité.
			if joueur.get("marque_cible") != null:
				_exploser_marque_derobade(joueur)
				return true

			# === CAS POSE ===
			# Pas de marque active → on en place une nouvelle.
			if not cible:
				print("Dérobade : une cible ennemie est requise pour poser la marque !")
				return false

			joueur.pm_actuels -= sort.cout_pm  # 2 PM à la pose
			sort.declencher_cooldown()         # CD 2 tours — pour limiter la repose après expiration

			joueur.marque_cible = cible
			joueur.marque_tours_restants = 3   # Tours 2 et 3 = déclenchables, Tour 4 = expiration
			print("🎯 Marque posée sur ", cible.name, " — 3 tours avant expiration (Touches : Z pour exploser)")
			_log("🎯 " + joueur.name + " marque " + cible.name + " — expire dans 3 tours", joueur)
			_rafraichir_hud()
			return true
		"fripon_lame":
			# Pas de cible — s'active sur soi-même
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			joueur.lame_active = true
			print("☠️ Lame Empoisonnée activée — prochaine attaque : +10 dmg + DoT")
			_log("☠️ " + joueur.name + " — Lame Empoisonnée activée", joueur)
			_rafraichir_hud()
			return true
		"fripon_frenesie":
			joueur.gold       -= sort.cout_gold
			joueur.pm_actuels -= sort.cout_pm
			sort.declencher_cooldown()
			joueur.frenesie_active = true
			print("🔥 Frénésie ! Attaques illimitées à 0 PM jusqu'à fin de tour")
			_log("🔥 " + joueur.name + " — Frénésie ! Attaques à 0 PM ce tour", joueur)
			_rafraichir_hud()
			return true
	return false

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

func _exploser_meteore(meteore: Dictionary):
	var cx = meteore["cible_x"]
	var cy = meteore["cible_y"]
	var lanceur = meteore["lanceur"]
	print("☄️ IMPACT du Météore en (", cx, ",", cy, ") !")
	var cases_transformees = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var x = cx + dx
			var y = cy + dy
			if x < 0 or x >= 8 or y < 0 or y >= 8:
				continue
			for j in [joueur1, joueur2, joueur3]:
				if j.est_place and not j.est_mort and j.grid_x == x and j.grid_y == y:
					var degats = 25 + lanceur.bonus_degats_sorts
					j.recevoir_degats(degats)
					lanceur.gagner_gold_sur_degats(degats)
					print("☄️ ", j.name, " — ", degats, " dmg")
			if board.get_case(x, y) == board.CaseType.TOUR:
				continue
			cases_transformees.append({"x": x, "y": y, "type_original": board.get_case(x, y)})
			board.plateau[x][y] = board.CaseType.LAVE
	laves_temporaires.append({"cases": cases_transformees, "tours_restants": 2})
	renderer.queue_redraw()
	print("🔥 ", cases_transformees.size(), " case(s) → Lave")

func _restaurer_cases_lave(lave: Dictionary):
	print("✨ Restauration Lave")
	for case_info in lave["cases"]:
		board.plateau[case_info["x"]][case_info["y"]] = case_info["type_original"]
		var j = _get_joueur_en(case_info["x"], case_info["y"])
		if j: _appliquer_effet_case(j)
	renderer.queue_redraw()

func _verifier_pieges(joueur: Node):
	var pieges_declenches = []
	for piege in pieges_actifs:
		if piege["x"] == joueur.grid_x and piege["y"] == joueur.grid_y and piege["poseur"] != joueur:
			joueur.recevoir_degats(10)
			joueur.tours_immobilise = 1
			pieges_declenches.append(piege)
			print("🪤 Piège déclenché ! 10 dmg + immobilisé 1 tour")
			# ← AJOUTE ICI
			_log("🪤 " + joueur.name + " déclenche un piège ! 10 dmg + immobilisé 1 tour", joueur)
	for piege in pieges_declenches:
		pieges_actifs.erase(piege)

func _restaurer_cases_foret(foret: Dictionary):
	print("🍂 Restauration Forêts temporaires")
	for case_info in foret["cases"]:
		board.plateau[case_info["x"]][case_info["y"]] = case_info["type_original"]
		var j = _get_joueur_en(case_info["x"], case_info["y"])
		if j: _appliquer_effet_case(j)
	renderer.queue_redraw()

# -----------------------------------------------
# Trouve la cible du rebond
#
# RÈGLES (conformes au Game Design) :
#   - Rayon ≤ 2 cases (distance Manhattan) autour de la CIBLE INITIALE
#   - Exclut le lanceur et la cible initiale elle-même
#   - Prend l'ennemi le plus proche dans ce rayon
#   - La ligne de vue est ensuite vérifiée dans _utiliser_sort
# -----------------------------------------------
func _trouver_rebond(lanceur: Node, cible_initiale: Node) -> Node:
	var meilleure_cible = null
	var meilleure_distance = 999
	for j in [joueur1, joueur2, joueur3]:
		if j == cible_initiale or j == lanceur:
			continue
		if not j.est_place or j.est_mort:
			continue
		# Distance depuis la CIBLE INITIALE — pas depuis le lanceur
		var distance = abs(j.grid_x - cible_initiale.grid_x) + abs(j.grid_y - cible_initiale.grid_y)
		# CORRECTION : rayon limité à 2 cases (était sans limite)
		if distance > 2:
			continue
		if distance < meilleure_distance:
			meilleure_distance = distance
			meilleure_cible = j
	return meilleure_cible

# -----------------------------------------------
# Ligne de vue (algorithme de Bresenham)
# Bloquée par MUR et VIDE — réutilisée pour :
#   → rebond de la Flèche (entre cible et rebond)
#   → Tir Ciblé
#   → Tempête Arcanique
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
		if not (x == x1 and y == y1) and not (x == x2 and y == y2):
			var type = board.get_case(x, y)
			if type == board.CaseType.MUR or type == board.CaseType.VIDE:
				return false
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

# Trouve la case libre la plus proche de (cible_x, cible_y)
# Utilisée par la Ruée du Fripon pour le repositionnement
func _trouver_case_libre_pres(cible_x: int, cible_y: int, lanceur: Node) -> Vector2i:
	var candidats = [
		Vector2i(cible_x - 1, cible_y),
		Vector2i(cible_x + 1, cible_y),
		Vector2i(cible_x, cible_y - 1),
		Vector2i(cible_x, cible_y + 1),
	]
	var meilleure = Vector2i(-1, -1)
	var meilleure_dist = 999
	for c in candidats:
		if c.x < 0 or c.x >= 8 or c.y < 0 or c.y >= 8:
			continue
		var type_case = board.get_case(c.x, c.y)
		if type_case == board.CaseType.VIDE or type_case == board.CaseType.MUR:
			continue
		if board.case_occupee(c.x, c.y):
			continue
		var dist = abs(c.x - lanceur.grid_x) + abs(c.y - lanceur.grid_y)
		if dist < meilleure_dist:
			meilleure_dist = dist
			meilleure = c
	return meilleure

# Explose la marque Dérobade au début du tour du Fripon
# Compte comme attaque de base pour les synergies (Lame, Ruée)
# NE consomme PAS a_attaque_ce_tour
func _exploser_marque_derobade(fripon: Node):
	var cible = fripon.marque_cible
	fripon.marque_cible = null  # Consomme la marque immédiatement

	# Sécurité : si la cible est morte ou non placée, on annule
	if not cible.est_place or cible.est_mort:
		print("🎯 Marque Dérobade — cible morte, pas d'explosion")
		return

	# --- Dégâts de base ---
	var degats = 10 + fripon.bonus_degats_sorts
	cible.recevoir_degats(degats)
	fripon.gagner_gold_sur_degats(degats)
	print("🎯 Explosion Dérobade ! ", degats, " dmg sur ", cible.name)
	_log("🎯 Explosion ! " + str(degats) + " dmg sur " + cible.name, fripon)

	# --- Synergie Lame Empoisonnée ---
	# L'explosion compte comme une attaque → déclenche la Lame si active
	# ID unique pour permettre le cumul (même principe que fripon.attaquer)
	if fripon.lame_active:
		cible.recevoir_degats(10)
		fripon.gagner_gold_sur_degats(10)
		cible.ajouter_dot("lame_empoisonnee", 5, 3)
		fripon.lame_active = false
		print("☠️ Lame + Dérobade — +10 dmg + DoT rafraîchi !")
	
	# --- Synergie Ruée — incrémente le compteur d'attaques ---
	# NE consomme PAS a_attaque_ce_tour
	fripon.attaques_depuis_ruee += 1
	if not fripon.ruee_disponible and fripon.attaques_depuis_ruee >= 3:
		fripon.ruee_disponible = true
		print("🗡️ Ruée déverrouillée via explosion Dérobade !")
	renderer.queue_redraw()

func _get_joueur_en(x: int, y: int) -> Node:
	for joueur in [joueur1, joueur2, joueur3]:
		if joueur.est_place and joueur.grid_x == x and joueur.grid_y == y:
			return joueur
	return null

func _on_joueur_mort(joueur: Node):
	board.liberer_case(joueur.grid_x, joueur.grid_y)
	_log("💀 " + joueur.name + " est éliminé !")  # blanc = système
	renderer.queue_redraw()


# -----------------------------------------------
# Callbacks événements
# -----------------------------------------------
func _on_evenement_declenche(nom: String):
	match nom:
		"mine_or":
			_log("⛏️ === 3 Mines d'Or sont apparues ! Détruisez-les pour du Gold ===")
		"coffre":
			_log("💎 === Un Coffre au Trésor est apparu ! Marchez dessus pour le ramasser ===")

		# ← AJOUTE CES DEUX CAS
		"tempete":
			# Déduit 1 PM à chaque joueur vivant, min 0
			for j in [joueur1, joueur2, joueur3]:
				if not j.est_mort:
					j.pm_malus_prochain_tour = 1
			_log("⚡ === Tempête Électrique ! Tous les joueurs perdent 1 PM ce tour ===")
			_rafraichir_hud()

		"inondation":
			# Applique l'effet Eau aux joueurs déjà sur les cases inondées
			for j in [joueur1, joueur2, joueur3]:
				if j.est_place and not j.est_mort:
					if board.get_case(j.grid_x, j.grid_y) == board.CaseType.EAU:
						_appliquer_effet_case(j)
			_log("🌊 === Inondation ! 4 cases deviennent Eau pendant 2 tours ===")
			renderer.queue_redraw()
			_rafraichir_hud()
			
func _on_piece_ramassee(joueur: Node, gold: int):
	_log("💰 " + joueur.name + " ramasse un tas de pièces ! +" + str(gold) + " Gold", joueur)
	_rafraichir_hud()
	renderer.queue_redraw()

func _on_coffre_ramasse(joueur: Node, gold: int):
	_log("💎 " + joueur.name + " ouvre le coffre ! +" + str(gold) + " Gold", joueur)
	_rafraichir_hud()
	renderer.queue_redraw()
