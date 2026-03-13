# hud_ui.gd
# -----------------------------------------------
# HUD UI — Panneau d'informations détaillées
# Ancré à droite de l'écran, toujours visible.
# Mis à jour depuis main.gd via rafraichir()
# après CHAQUE action du joueur.
# -----------------------------------------------
extends CanvasLayer

# Touches associées aux sorts dans l'ordre
const TOUCHES = ["A", "Z", "E", "R"]

# Couleurs des joueurs en hexadécimal BBCode
# Alignées avec renderer.gd et log_ui.gd
const COULEURS_JOUEURS = ["#ffff00", "#00ffff", "#00ff00"]

# Référence au board — assignée par main.gd dans _ready()
# Nécessaire pour lire le type de la case actuelle du joueur
var board: Node = null

# Les 3 RichTextLabel, un par joueur — créés dans _ready()
var _labels: Array = []

var _panel: PanelContainer = null
# -----------------------------------------------
# _ready — Construit toute l'interface en code
# Pas de .tscn nécessaire sauf le nœud racine
# -----------------------------------------------
func _ready():
	# --- Conteneur principal ancré à droite ---
	var panel = PanelContainer.new()
	_panel = panel  # On garde la référence pour le resize
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -305  # Largeur du HUD = 305px
	panel.offset_right  = 0
	panel.offset_top    = 0
	panel.offset_bottom = 0
	add_child(panel)

	# --- ScrollContainer — gère le débordement vertical ---
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)

	# --- VBoxContainer — empile les blocs joueur ---
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(295, 0)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Titre du panneau
	var titre = Label.new()
	titre.text = "📊 Informations"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(titre)

	var taille = get_viewport().get_visible_rect().size
	bouton_fin_tour.set_position(Vector2(
		taille.x / 2 - 60,   # Centré horizontalement
		taille.y - 50         # Collé en bas
	))
	# Crée un bloc RichTextLabel par joueur (3 joueurs)
	for i in range(3):
		vbox.add_child(HSeparator.new())

		var rtl = RichTextLabel.new()
		rtl.bbcode_enabled = true      # Active le BBCode pour les couleurs
		rtl.fit_content = true         # Hauteur automatique selon le contenu
		rtl.custom_minimum_size = Vector2(290, 10)
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(rtl)
		_labels.append(rtl)

# -----------------------------------------------
# rafraichir — Appelé par main.gd après chaque action
# joueurs     : [joueur1, joueur2, joueur3]
# joueur_actif : le joueur dont c'est le tour
# -----------------------------------------------
func rafraichir(joueurs: Array, joueur_actif: Node):
	for i in range(joueurs.size()):
		if i >= _labels.size():
			break
		# Reconstruit le texte BBCode entier pour ce joueur
		_labels[i].text = _construire_texte(joueurs[i], joueur_actif, i, joueurs)

# -----------------------------------------------
# _construire_texte — Génère le BBCode d'un joueur
# Appelé par rafraichir() pour chaque joueur
# -----------------------------------------------
func _construire_texte(joueur: Node, joueur_actif: Node, index: int, tous: Array) -> String:
	var c = COULEURS_JOUEURS[index]
	var txt = ""

	# === Joueur éliminé ===
	if joueur.est_mort:
		return "[color=#888888]💀 " + joueur.name + " — ÉLIMINÉ[/color]"

	# === Nom + Classe + indicateur tour actif ===
	var actif_str = "  [color=#ffffff]◄ TON TOUR[/color]" if joueur == joueur_actif else ""
	txt += "[color=" + c + "][b]" + joueur.name
	txt += "  [" + _get_nom_classe(joueur) + "][/b]" + actif_str + "\n"

	# === Barre de vie ===
	# Rouge si < 30%, jaune si < 60%, vert sinon
	var pct_hp = float(joueur.hp_actuels) / float(joueur.hp_max)
	var c_hp = "#ff4444" if pct_hp < 0.3 else ("#ffff44" if pct_hp < 0.6 else "#44ff44")
	txt += "[color=" + c_hp + "]❤️  "
	txt += str(joueur.hp_actuels) + "/" + str(joueur.hp_max)
	txt += "  " + _barre(pct_hp, 14) + "[/color]\n"

	# === Barre de PM ===
	var pct_pm = float(joueur.pm_actuels) / float(joueur.pm_max) if joueur.pm_max > 0 else 0.0
	txt += "[color=#4488ff]🔵 PM: "
	txt += str(joueur.pm_actuels) + "/" + str(joueur.pm_max)
	txt += "  " + _barre(pct_pm, 10) + "[/color]\n"

	# === Gold ===
	txt += "[color=#ffcc00]💰 Gold: " + str(joueur.gold) + "[/color]\n"

	# === Case actuelle et son effet ===
	if joueur.est_place:
		txt += "🗺️ Case (" + str(joueur.grid_x) + "," + str(joueur.grid_y) + ")  "
		txt += _get_effet_case(joueur) + "\n"

	# === Effets de statut actifs ===
	# DoT, Gel, Rage, Frénésie, Lame, Résistances, Marque Dérobade...
	var effets = _get_effets_actifs(joueur, tous)
	if effets != "":
		txt += effets + "\n"

	# === Sorts avec cooldown ===
	txt += "[color=#cc88ff]🔮 Sorts:[/color]\n"
	for i in range(joueur.sorts.size()):
		var sort = joueur.sorts[i]
		var touche = TOUCHES[i] if i < TOUCHES.size() else "?"

		if sort.est_disponible():
			# Sort disponible — vert avec coche
			txt += "  [color=#00ff88][" + touche + "] " + sort.nom + " ✅[/color]"
		else:
			# Sort en cooldown — rouge avec compteur
			txt += "  [color=#ff4444][" + touche + "] " + sort.nom
			txt += " 🔄" + str(sort.cooldown_actuel) + "T[/color]"

		# Coût PM et Gold en gris
		txt += " [color=#888888](" + str(sort.cout_pm) + "PM"
		if sort.cout_gold > 0:
			txt += "/" + str(sort.cout_gold) + "G"
		txt += ")[/color]\n"

	return txt

# -----------------------------------------------
# _barre — Génère une barre de progression textuelle
# pct      : valeur entre 0.0 et 1.0
# longueur : nombre total de caractères
# Exemple : [████████░░░░░░] pour pct=0.57
# -----------------------------------------------
func _barre(pct: float, longueur: int) -> String:
	var rempli = int(clamp(pct, 0.0, 1.0) * longueur)
	var vide   = longueur - rempli
	return "[" + "█".repeat(rempli) + "░".repeat(vide) + "]"

# -----------------------------------------------
# _get_nom_classe — Lit le script du joueur pour
# en déduire sa classe (Guerrier, Mage, etc.)
# -----------------------------------------------
func _get_nom_classe(joueur: Node) -> String:
	var path = joueur.get_script().resource_path
	if "fripon"   in path: return "Fripon"
	if "mage"     in path: return "Mage"
	if "guerrier" in path: return "Guerrier"
	if "archer"   in path: return "Archer"
	return "?"

# -----------------------------------------------
# _get_effet_case — Description colorée de la case
# selon son type (LAVE, EAU, FORET, etc.)
# -----------------------------------------------
func _get_effet_case(joueur: Node) -> String:
	if board == null or not joueur.est_place:
		return ""
	match board.get_case(joueur.grid_x, joueur.grid_y):
		0: return "[color=#aaaaaa]Normal[/color]"
		1: return "[color=#ff4400]🔥 Lave (-10 HP/tour)[/color]"
		2: return "[color=#4488ff]💧 Eau (+10 HP/tour)[/color]"
		3: return "[color=#444444]⬛ Vide[/color]"
		4: return "[color=#44bb44]🌲 Forêt (+10% résist, 2PM/case)[/color]"
		5: return "[color=#886644]🧱 Mur[/color]"
		6: return "[color=#ccaa00]🏰 Tour (+1 portée sorts)[/color]"
	return ""

# -----------------------------------------------
# _get_effets_actifs — Liste tous les effets actifs
# sur un joueur : DoT, Gel, Rage, Frénésie, etc.
# tous : nécessaire pour détecter la Marque Dérobade
# -----------------------------------------------
func _get_effets_actifs(joueur: Node, tous: Array) -> String:
	var effets = []

	# DoT actifs (hache empoisonnée, lame empoisonnée...)
	for source_id in joueur.dots_actifs:
		var dot = joueur.dots_actifs[source_id]
		effets.append(
			"[color=#ff8800]  ☠️ DoT '" + source_id + "' : "
			+ str(dot["degats"]) + "/tour (" + str(dot["tours_restants"]) + "T)[/color]"
		)

	# Gel — immobilisation
	if joueur.tours_immobilise > 0:
		effets.append("[color=#00ccff]  ❄️ Gel — immobilisé (" + str(joueur.tours_immobilise) + "T)[/color]")

	# Résistance de case (Forêt = 10%, Tour = 0%)
	if joueur.resistance_case > 0.0:
		effets.append(
			"[color=#44bb44]  🛡️ Résistance case : +"
			+ str(int(joueur.resistance_case * 100)) + "%[/color]"
		)

	# Résistance permanente (Amulette de Résistance)
	if joueur.resistance_degats > 0.0:
		effets.append(
			"[color=#88ff88]  🛡️ Résistance perma : +"
			+ str(int(joueur.resistance_degats * 100)) + "%[/color]"
		)

	# Rage Berserker — spécifique au Guerrier
	if joueur.get("rage_active") != null and joueur.rage_active:
		effets.append("[color=#ff4444]  ⚔️ Rage Berserker (" + str(joueur.tours_rage_restants) + "T)[/color]")

	# Frénésie — spécifique au Fripon (attaques à 0 PM)
	if joueur.get("frenesie_active") != null and joueur.frenesie_active:
		effets.append("[color=#ffff44]  🔥 Frénésie — attaques à 0 PM ![/color]")

	# Lame Empoisonnée prête (Fripon)
	if joueur.get("lame_active") != null and joueur.lame_active:
		effets.append("[color=#cc44ff]  ☠️ Lame Empoisonnée prête[/color]")

	# Ruée — disponible ou verrouillée (Fripon)
	if joueur.get("ruee_disponible") != null:
		if joueur.ruee_disponible:
			effets.append("[color=#44ffcc]  🗡️ Ruée disponible[/color]")
		else:
			var restantes = 3 - joueur.attaques_depuis_ruee
			effets.append("[color=#888888]  🗡️ Ruée — encore " + str(restantes) + " attaque(s)[/color]")

	# Ce joueur a posé une marque Dérobade sur quelqu'un
	if joueur.get("marque_cible") != null:
		effets.append(
			"[color=#ff88ff]  🎯 Marque posée sur "
			+ joueur.marque_cible.name
			+ " (" + str(joueur.marque_tours_restants) + "T)[/color]"
		)

	# Ce joueur EST marqué par un Fripon ennemi
	for autre in tous:
		if autre == joueur: continue
		if autre.get("marque_cible") != null and autre.marque_cible == joueur:
			effets.append(
				"[color=#ff44ff]  🎯 MARQUÉ par "
				+ autre.name
				+ " (" + str(autre.marque_tours_restants) + "T)[/color]"
			)

	return "\n".join(effets)

# -----------------------------------------------
# Repositionne le HUD quand la fenêtre est redimensionnée
# Appelé automatiquement par Godot
# -----------------------------------------------
func _notification(what):
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_repositionner()

func _repositionner():
	if _panel == null:
		return
	var taille = get_viewport().get_visible_rect().size
	# Stick à droite : x = largeur fenêtre - largeur HUD
	_panel.set_position(Vector2(taille.x - 260, 0))
	_panel.set_size(Vector2(260, taille.y))
