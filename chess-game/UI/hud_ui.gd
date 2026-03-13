# =======================================================
# UI/hud_ui.gd
# -------------------------------------------------------
# HUD — Panneau d'informations détaillées ancré à droite.
# Construit entièrement en code (pas de .tscn).
#
#   - 1 bloc par joueur avec HP, PM, Gold, case, sorts, effets
#   - Barres de progression textuelles
#   - Couleurs BBCode par joueur et par état (Rage, Frénésie, etc.)
#   - Mis à jour via rafraichir() après chaque action
#
# NE contient PAS de logique de gameplay.
# =======================================================
extends CanvasLayer


# =======================================================
# CONSTANTES — Layout
# =======================================================

const HUD_LARGEUR       : int = 305  # Largeur du panneau en pixels
const BARRE_LONGUEUR_HP : int = 14   # Nombre de caractères pour la barre de vie
const BARRE_LONGUEUR_PM : int = 10   # Nombre de caractères pour la barre de PM


# =======================================================
# CONSTANTES — Couleurs des joueurs (BBCode)
# Alignées avec renderer.gd (COULEURS_JOUEURS)
# =======================================================

const COULEUR_J1 : String = "#ffff00"  # Jaune
const COULEUR_J2 : String = "#00ffff"  # Cyan
const COULEUR_J3 : String = "#00ff00"  # Vert

const COULEURS_JOUEURS : Array = [COULEUR_J1, COULEUR_J2, COULEUR_J3]


# =======================================================
# CONSTANTES — Touches des sorts (dans l'ordre)
# =======================================================

const TOUCHES_SORTS : Array = ["A", "Z", "E", "R"]


# =======================================================
# RÉFÉRENCES — Injectées par main.gd
# =======================================================

var board : Node = null  # Nécessaire pour lire le type de la case actuelle


# =======================================================
# NŒUDS — Construits dans _ready()
# =======================================================

var _panel  : PanelContainer = null
var _labels : Array          = []   # Un RichTextLabel par joueur


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	_construire_panel()


# -------------------------------------------------------
# Construit le panneau principal et les blocs joueurs.
# -------------------------------------------------------
func _construire_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left   = 1.0
	_panel.anchor_right  = 1.0
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left   = -HUD_LARGEUR
	_panel.offset_right  = 0
	_panel.offset_top    = 0
	_panel.offset_bottom = 0
	add_child(_panel)

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(scroll)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size      = Vector2(HUD_LARGEUR - 10, 0)
	vbox.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var titre : Label = Label.new()
	titre.text                 = "📊 Informations"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(titre)

	# Un RichTextLabel par joueur
	for _i in range(3):
		vbox.add_child(HSeparator.new())
		var rtl : RichTextLabel = RichTextLabel.new()
		rtl.bbcode_enabled            = true
		rtl.fit_content               = true
		rtl.custom_minimum_size       = Vector2(HUD_LARGEUR - 15, 10)
		rtl.size_flags_horizontal     = Control.SIZE_EXPAND_FILL
		vbox.add_child(rtl)
		_labels.append(rtl)


# =======================================================
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Rafraîchit l'affichage de tous les joueurs.
# Appelée par main.gd via _rafraichir_hud() après chaque action.
# -------------------------------------------------------
func rafraichir(joueurs: Array, joueur_actif: Node) -> void:
	for i in range(joueurs.size()):
		if i >= _labels.size():
			break
		_labels[i].text = _construire_texte(joueurs[i], joueur_actif, i, joueurs)


# =======================================================
# CONSTRUCTION DU TEXTE BBCode
# =======================================================

# -------------------------------------------------------
# Génère le texte BBCode complet pour un joueur.
# -------------------------------------------------------
func _construire_texte(joueur: Node, joueur_actif: Node, index: int, tous: Array) -> String:
	if joueur.est_mort:
		return "[color=#888888]💀 %s — ÉLIMINÉ[/color]" % joueur.name

	var c   : String = COULEURS_JOUEURS[index]
	var txt : String = ""

	# --- Nom + Classe + indicateur de tour ---
	var actif_str : String = "  [color=#ffffff]◄ TON TOUR[/color]" if joueur == joueur_actif else ""
	txt += "[color=%s][b]%s  [%s][/b]%s\n" % [c, joueur.name, _get_nom_classe(joueur), actif_str]

	# --- Barre de vie (couleur selon pourcentage) ---
	var pct_hp  : float  = float(joueur.hp_actuels) / float(joueur.hp_max)
	var c_hp    : String = "#ff4444" if pct_hp < 0.3 else ("#ffff44" if pct_hp < 0.6 else "#44ff44")
	txt += "[color=%s]❤️  %d/%d  %s[/color]\n" % [c_hp, joueur.hp_actuels, joueur.hp_max, _barre(pct_hp, BARRE_LONGUEUR_HP)]

	# --- Barre de PM ---
	var pct_pm : float = float(joueur.pm_actuels) / float(joueur.pm_max) if joueur.pm_max > 0 else 0.0
	txt += "[color=#4488ff]🔵 PM: %d/%d  %s[/color]\n" % [joueur.pm_actuels, joueur.pm_max, _barre(pct_pm, BARRE_LONGUEUR_PM)]

	# --- Gold ---
	txt += "[color=#ffcc00]💰 Gold: %d[/color]\n" % joueur.gold

	# --- Case actuelle ---
	if joueur.est_place:
		txt += "🗺️ Case (%d,%d)  %s\n" % [joueur.grid_x, joueur.grid_y, _get_texte_case(joueur)]

	# --- Effets de statut ---
	var effets : String = _get_effets_actifs(joueur, tous)
	if effets != "":
		txt += effets + "\n"

	# --- Sorts avec cooldown ---
	txt += "[color=#cc88ff]🔮 Sorts:[/color]\n"
	for i in range(joueur.sorts.size()):
		var sort   : Resource = joueur.sorts[i]
		var touche : String   = TOUCHES_SORTS[i] if i < TOUCHES_SORTS.size() else "?"
		var cout   : String   = "(%dPM%s)" % [sort.cout_pm, ("/%dG" % sort.cout_gold) if sort.cout_gold > 0 else ""]

		if sort.est_disponible():
			txt += "  [color=#00ff88][%s] %s ✅[/color] [color=#888888]%s[/color]\n" % [touche, sort.nom, cout]
		else:
			txt += "  [color=#ff4444][%s] %s 🔄%dT[/color] [color=#888888]%s[/color]\n" % [touche, sort.nom, sort.cooldown_actuel, cout]

	return txt


# =======================================================
# HELPERS — Texte de statut
# =======================================================

# -------------------------------------------------------
# Barre de progression textuelle — ex: [████████░░░░░░]
# pct : 0.0 → 1.0
# -------------------------------------------------------
func _barre(pct: float, longueur: int) -> String:
	var rempli : int = int(clamp(pct, 0.0, 1.0) * longueur)
	return "[" + "█".repeat(rempli) + "░".repeat(longueur - rempli) + "]"


# -------------------------------------------------------
# Détermine la classe d'un joueur via son resource_path
# -------------------------------------------------------
func _get_nom_classe(joueur: Node) -> String:
	var path : String = joueur.get_script().resource_path
	if "fripon"   in path: return "Fripon"
	if "mage"     in path: return "Mage"
	if "guerrier" in path: return "Guerrier"
	if "archer"   in path: return "Archer"
	return "?"


# -------------------------------------------------------
# Retourne la description colorée de la case actuelle du joueur
# -------------------------------------------------------
func _get_texte_case(joueur: Node) -> String:
	if board == null or not joueur.est_place:
		return ""
	match board.get_case(joueur.grid_x, joueur.grid_y):
		0: return "[color=#aaaaaa]Normal[/color]"
		1: return "[color=#ff4400]🔥 Lave (-10 HP/tour)[/color]"
		2: return "[color=#4488ff]💧 Eau (+10 HP/tour)[/color]"
		3: return "[color=#444444]⬛ Vide[/color]"
		4: return "[color=#44bb44]🌲 Forêt (+10% résist, 2PM)[/color]"
		5: return "[color=#886644]🧱 Mur[/color]"
		6: return "[color=#ccaa00]🏰 Tour (+1 portée sorts)[/color]"
	return ""


# -------------------------------------------------------
# Retourne la liste BBCode de tous les effets actifs sur un joueur.
# tous : nécessaire pour détecter si ce joueur est marqué par un Fripon.
# -------------------------------------------------------
func _get_effets_actifs(joueur: Node, tous: Array) -> String:
	var effets : Array = []

	# DoT actifs
	for source_id in joueur.dots_actifs:
		var dot : Dictionary = joueur.dots_actifs[source_id]
		effets.append("[color=#ff8800]  ☠️ DoT '%s' : %d/tour (%dT)[/color]" % [
			source_id, dot["degats"], dot["tours_restants"]
		])

	# Immobilisation (Gel, Piège)
	if joueur.tours_immobilise > 0:
		effets.append("[color=#00ccff]  ❄️ Gel — immobilisé (%dT)[/color]" % joueur.tours_immobilise)

	# Résistance de case (Forêt)
	if joueur.resistance_case > 0.0:
		effets.append("[color=#44bb44]  🛡️ Résistance case : +%.0f%%[/color]" % (joueur.resistance_case * 100))

	# Résistance permanente (Amulette, Armure)
	if joueur.resistance_degats > 0.0:
		effets.append("[color=#88ff88]  🛡️ Résistance perma : +%.0f%%[/color]" % (joueur.resistance_degats * 100))

	# Rage Berserker (Guerrier)
	if joueur.get("rage_active") != null and joueur.rage_active:
		effets.append("[color=#ff4444]  ⚔️ Rage Berserker (%dT)[/color]" % joueur.tours_rage_restants)

	# Frénésie (Fripon)
	if joueur.get("frenesie_active") != null and joueur.frenesie_active:
		effets.append("[color=#ffff44]  🔥 Frénésie — attaques à 0 PM ![/color]")

	# Lame Empoisonnée prête (Fripon)
	if joueur.get("lame_active") != null and joueur.lame_active:
		effets.append("[color=#cc44ff]  ☠️ Lame Empoisonnée prête[/color]")

	# Ruée — disponible ou en recharge (Fripon)
	if joueur.get("ruee_disponible") != null:
		if joueur.ruee_disponible:
			effets.append("[color=#44ffcc]  🗡️ Ruée disponible[/color]")
		else:
			var restantes : int = 3 - joueur.attaques_depuis_ruee
			effets.append("[color=#888888]  🗡️ Ruée — encore %d attaque(s)[/color]" % restantes)

	# Marque posée (ce joueur a marqué un ennemi — Fripon)
	if joueur.get("marque_cible") != null:
		effets.append("[color=#ff88ff]  🎯 Marque posée sur %s (%dT)[/color]" % [
			joueur.marque_cible.name, joueur.marque_tours_restants
		])

	# Marqué par un Fripon ennemi
	for autre in tous:
		if autre == joueur:
			continue
		if autre.get("marque_cible") != null and autre.marque_cible == joueur:
			effets.append("[color=#ff44ff]  🎯 MARQUÉ par %s (%dT)[/color]" % [
				autre.name, autre.marque_tours_restants
			])

	return "\n".join(effets)


# =======================================================
# REPOSITIONNEMENT
# =======================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_repositionner()


func _repositionner() -> void:
	if _panel == null:
		return
	var taille : Vector2 = get_viewport().get_visible_rect().size
	_panel.set_position(Vector2(taille.x - HUD_LARGEUR, 0))
	_panel.set_size(Vector2(HUD_LARGEUR, taille.y))
