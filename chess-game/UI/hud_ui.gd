# =======================================================
# UI/hud_ui.gd
# -------------------------------------------------------
# HUD joueurs — colonne à droite de l'écran.
# Construit entièrement en code (pas de .tscn).
#
#   - 1 card par joueur : HP/PM (ProgressBar), Gold, effets
#   - Card du joueur actif mise en surbrillance
#   - Mis à jour via rafraichir(joueurs, joueur_actif)
#
# NE contient PAS de logique de gameplay.
# =======================================================
extends CanvasLayer


# =======================================================
# CONSTANTES — Layout
# =======================================================

const HUD_LARGEUR      : int = 220
const HUD_MARGE_DROITE : int = 8
const HUD_MARGE_HAUT   : int = 8
const HUD_ESPACEMENT   : int = 6
const FONT_SIZE_NOM    : int = 13
const FONT_SIZE_STATS  : int = 11


# =======================================================
# CONSTANTES — Couleurs
# =======================================================

const COULEUR_FOND          : Color = Color(0.07, 0.07, 0.15, 0.92)
const COULEUR_FOND_ACTIF    : Color = Color(0.12, 0.12, 0.28, 0.97)
const COULEUR_FOND_MORT     : Color = Color(0.07, 0.07, 0.07, 0.80)
const COULEUR_BORDURE       : Color = Color(0.25, 0.25, 0.45, 1.0)
const COULEUR_BORDURE_ACTIF : Color = Color(0.6,  0.6,  1.0,  1.0)
const COULEUR_HP_HAUT       : Color = Color(0.18, 0.75, 0.35)
const COULEUR_HP_MOYEN      : Color = Color(0.85, 0.65, 0.10)
const COULEUR_HP_BAS        : Color = Color(0.85, 0.20, 0.20)
const COULEUR_PM            : Color = Color(0.20, 0.55, 0.95)
const COULEUR_GOLD          : Color = Color(0.95, 0.80, 0.10)
const COULEUR_TEXTE         : Color = Color(0.85, 0.85, 0.85)
const COULEUR_MORT          : Color = Color(0.35, 0.35, 0.35)
const COULEUR_J1            : Color = Color(1.0,  1.0,  0.0)
const COULEUR_J2            : Color = Color(0.0,  1.0,  1.0)
const COULEUR_J3            : Color = Color(0.0,  1.0,  0.0)
const COULEURS_JOUEURS      : Array[Color] = [COULEUR_J1, COULEUR_J2, COULEUR_J3]


# =======================================================
# RÉFÉRENCES — Injectées par main.gd
# =======================================================

var tour_manager : Node = null
var board        : Node = null  # Injectée par main.gd


# =======================================================
# NŒUDS — Construits dans _ready()
# =======================================================

var _conteneur : VBoxContainer = null


# =======================================================
# INITIALISATION
# =======================================================

func _ready() -> void:
	layer = 8

	_conteneur = VBoxContainer.new()
	_conteneur.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_conteneur.anchor_left     = 1.0
	_conteneur.anchor_right    = 1.0
	_conteneur.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_conteneur.offset_right    = -HUD_MARGE_DROITE
	_conteneur.offset_top      = HUD_MARGE_HAUT
	_conteneur.add_theme_constant_override("separation", HUD_ESPACEMENT)
	add_child(_conteneur)


# =======================================================
# API PUBLIQUE
# =======================================================

func rafraichir(joueurs: Array[Node], joueur_actif: Node) -> void:
	for enfant in _conteneur.get_children():
		enfant.queue_free()

	for i in range(joueurs.size()):
		var card := _creer_card(joueurs[i], i, joueur_actif)
		_conteneur.add_child(card)


# =======================================================
# CONSTRUCTION D'UNE CARD JOUEUR
# =======================================================

func _creer_card(joueur: Node, index: int, joueur_actif: Node) -> PanelContainer:
	var card      := PanelContainer.new()
	var est_actif : bool = joueur == joueur_actif
	var est_mort  : bool = joueur.est_mort

	var style := StyleBoxFlat.new()
	style.bg_color     = COULEUR_FOND_MORT if est_mort else (COULEUR_FOND_ACTIF if est_actif else COULEUR_FOND)
	style.border_color = COULEUR_BORDURE_ACTIF if est_actif else COULEUR_BORDURE
	style.set_border_width_all(2 if est_actif else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 8.0
	style.content_margin_right  = 8.0
	style.content_margin_top    = 6.0
	style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(HUD_LARGEUR, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var couleur_j : Color = COULEURS_JOUEURS[index] if index < COULEURS_JOUEURS.size() else COULEUR_TEXTE

	# Joueur éliminé — card simplifiée
	if est_mort:
		var label := Label.new()
		label.text = "💀 %s — ÉLIMINÉ" % joueur.name
		label.add_theme_font_size_override("font_size", FONT_SIZE_NOM)
		label.add_theme_color_override("font_color", COULEUR_MORT)
		vbox.add_child(label)
		return card

	# Nom + classe
	var label_nom := Label.new()
	label_nom.text = "%s  [%s]" % [joueur.name, _get_classe(joueur)]
	label_nom.add_theme_font_size_override("font_size", FONT_SIZE_NOM)
	label_nom.add_theme_color_override("font_color", couleur_j)
	vbox.add_child(label_nom)

	if est_actif:
		var label_actif := Label.new()
		label_actif.text = "◄ TON TOUR"
		label_actif.add_theme_font_size_override("font_size", 10)
		label_actif.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(label_actif)

	# HP
	var pct_hp : float = float(joueur.hp_actuels) / float(joueur.hp_max) if joueur.hp_max > 0 else 0.0
	_ajouter_stat(vbox, "❤️ %d / %d" % [joueur.hp_actuels, joueur.hp_max],
		joueur.hp_actuels, joueur.hp_max, _couleur_hp(pct_hp))

	# PM
	_ajouter_stat(vbox, "🔵 %d / %d PM" % [joueur.pm_actuels, joueur.pm_max],
		joueur.pm_actuels, joueur.pm_max, COULEUR_PM)

	# Gold
	var label_gold := Label.new()
	label_gold.text = "💰 %d Gold" % joueur.gold
	label_gold.add_theme_font_size_override("font_size", FONT_SIZE_STATS)
	label_gold.add_theme_color_override("font_color", COULEUR_GOLD)
	vbox.add_child(label_gold)

	# -------------------------------------------------------
	# Case actuelle + modificateurs
	# N'affiche RIEN pour une case NORMAL (pas d'effet)
	# -------------------------------------------------------
	var type_case    : int    = board.get_case(joueur.grid_x, joueur.grid_y) if board != null else -1
	var nom_case     : String = _get_nom_case(type_case)
	var modif_case   : String = _get_modif_case(type_case)
	var couleur_case : Color  = _get_couleur_case(type_case)

	if nom_case != "":
		var label_case := Label.new()
		label_case.text = "📍 %s  %s" % [nom_case, modif_case]
		label_case.add_theme_font_size_override("font_size", FONT_SIZE_STATS)
		label_case.add_theme_color_override("font_color", couleur_case)
		label_case.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(label_case)

	# Résistance de case active (Forêt)
	if joueur.resistance_case > 0.0:
		var label_res := Label.new()
		label_res.text = "🛡 Résistance case : +%.0f%%" % (joueur.resistance_case * 100)
		label_res.add_theme_font_size_override("font_size", FONT_SIZE_STATS - 1)
		label_res.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
		vbox.add_child(label_res)

	# Effets de statut
	var effets_texte : String = _get_effets(joueur)
	if effets_texte != "":
		var label_effets := Label.new()
		label_effets.text            = effets_texte
		label_effets.add_theme_font_size_override("font_size", 10)
		label_effets.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		label_effets.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(label_effets)

	return card


# =======================================================
# HELPERS — Stat avec ProgressBar
# =======================================================

func _ajouter_stat(parent: VBoxContainer, texte: String, val: int, max_val: int, couleur: Color) -> void:
	var label := Label.new()
	label.text = texte
	label.add_theme_font_size_override("font_size", FONT_SIZE_STATS)
	label.add_theme_color_override("font_color", couleur)
	parent.add_child(label)

	var barre := ProgressBar.new()
	barre.min_value           = 0
	barre.max_value           = max(1, max_val)
	barre.value               = val
	barre.show_percentage     = false
	barre.custom_minimum_size = Vector2(0, 6)

	var fill := StyleBoxFlat.new()
	fill.bg_color = couleur
	barre.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	barre.add_theme_stylebox_override("background", bg)

	parent.add_child(barre)


# =======================================================
# HELPERS — Couleur et texte
# =======================================================

func _couleur_hp(pct: float) -> Color:
	if pct < 0.3: return COULEUR_HP_BAS
	if pct < 0.6: return COULEUR_HP_MOYEN
	return COULEUR_HP_HAUT


func _get_classe(joueur: Node) -> String:
	return joueur.get_classe().capitalize()


# -------------------------------------------------------
# Retourne le nom lisible du type de case.
# Retourne "" pour NORMAL — aucun effet, rien à afficher.
# -------------------------------------------------------
func _get_nom_case(type_case: int) -> String:
	match type_case:
		1: return "Lave 🔥"
		2: return "Eau 💧"
		3: return "Vide ⬛"
		4: return "Forêt 🌲"
		5: return "Mur 🧱"
		6: return "Tour 🏰"
	return ""


# -------------------------------------------------------
# Retourne les modificateurs de la case sous forme lisible.
# -------------------------------------------------------
func _get_modif_case(type_case: int) -> String:
	match type_case:
		1: return "(-10 HP/tour)"
		2: return "(+10 HP/tour)"
		4: return "(-1 PM • +10% résist.)"
		6: return "(+1 portée sorts)"
	return ""


# -------------------------------------------------------
# Retourne la couleur associée au type de case.
# -------------------------------------------------------
func _get_couleur_case(type_case: int) -> Color:
	match type_case:
		1: return Color(1.0,  0.35, 0.1)   # Lave    — orange/rouge
		2: return Color(0.2,  0.6,  1.0)   # Eau     — bleu
		3: return Color(0.35, 0.35, 0.35)  # Vide    — gris
		4: return Color(0.2,  0.8,  0.3)   # Forêt   — vert
		5: return Color(0.6,  0.5,  0.4)   # Mur     — marron
		6: return Color(0.95, 0.82, 0.2)   # Tour    — doré
	return Color(0.7, 0.7, 0.7)


func _get_effets(joueur: Node) -> String:
	var parties : Array[String] = []

	if joueur.tours_immobilise > 0:
		parties.append("❄️ Gel (%dT)" % joueur.tours_immobilise)

	for source_id in joueur.dots_actifs:
		var dot : Dictionary = joueur.dots_actifs[source_id]
		parties.append("☠️ DoT %d/T (%dT)" % [dot["degats"], dot["tours_restants"]])

	if joueur.resistance_degats > 0.0:
		parties.append("🛡️ +%.0f%% rés." % (joueur.resistance_degats * 100))

	if joueur.get("rage_active") != null and joueur.rage_active:
		parties.append("⚔️ Rage (%dT)" % joueur.tours_rage_restants)

	if joueur.get("frenesie_active") != null and joueur.frenesie_active:
		parties.append("🔥 Frénésie")

	if joueur.get("lame_active") != null and joueur.lame_active:
		parties.append("☠️ Lame prête")

	return "\n".join(parties)
