# =======================================================
# UI/sort_ui.gd
# -------------------------------------------------------
# Affiche les sorts du joueur actif sous forme de cards
# cliquables en bas de l'écran.
#
# Chaque card montre :
#   - Nom du sort
#   - Description courte
#   - Coût PM + Coût Gold (si > 0)
#   - Dégâts (si > 0)
#   - Portée
#   - Cooldown restant (si en recharge)
#
# États visuels d'une card :
#   - Normal      → sort disponible et débloqué
#   - Grisé       → sort verrouillé (pas encore débloqué ce tour)
#   - Orange      → sort en cooldown (X tours restants)
#   - Rouge foncé → PM insuffisants
#
# Le clic sur une card sélectionne/désélectionne le sort,
# exactement comme les touches A/Z/E/R le faisaient.
# =======================================================
extends CanvasLayer


# =======================================================
# CONSTANTES — Dimensions des cards
# =======================================================

const CARD_LARGEUR    : int = 200   # Largeur d'une card en pixels
const CARD_HAUTEUR    : int = 140   # Hauteur d'une card en pixels
const CARD_ESPACEMENT : int = 12    # Espace entre deux cards
const CARD_MARGE_BAS  : int = 30    # Marge par rapport au bas de l'écran

# Couleurs de fond selon l'état de la card
const COULEUR_DISPONIBLE  : Color = Color(0.15, 0.15, 0.25, 0.92)  # Bleu sombre — disponible
const COULEUR_SELECTIONNE : Color = Color(0.35, 0.1,  0.6,  0.95)  # Violet — sélectionné
const COULEUR_COOLDOWN    : Color = Color(0.35, 0.2,  0.05, 0.92)  # Orange sombre — cooldown
const COULEUR_VEROUILLE   : Color = Color(0.12, 0.12, 0.12, 0.88)  # Gris foncé — verrouillé
const COULEUR_PM_INSUF    : Color = Color(0.25, 0.05, 0.05, 0.92)  # Rouge foncé — PM insuffisants
const COULEUR_BORDURE_SEL : Color = Color(0.7,  0.3,  1.0,  1.0)   # Violet vif — bordure sélectionné


# =======================================================
# RÉFÉRENCES — Injectées par main.gd
# =======================================================

var joueur_actif  : Node = null  # Joueur dont c'est le tour
var input_handler : Node = null  # Pour lire/écrire sort_selectionne
var renderer      : Node = null  # Pour appeler rafraichir() après sélection


# =======================================================
# ÉTAT INTERNE
# =======================================================

# Conteneur principal centré en bas de l'écran
var _conteneur : HBoxContainer = null


# =======================================================
# INITIALISATION
# =======================================================

func _ready() -> void:
	layer = 10  # Au-dessus du jeu 3D, en-dessous de l'inventaire

	# Crée le conteneur des cards centré horizontalement en bas
	_conteneur = HBoxContainer.new()
	_conteneur.add_theme_constant_override("separation", CARD_ESPACEMENT)
	_conteneur.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_conteneur.anchor_top    = 1.0
	_conteneur.anchor_bottom = 1.0
	_conteneur.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_conteneur.offset_bottom = -CARD_MARGE_BAS
	_conteneur.offset_top    = -(CARD_HAUTEUR + CARD_MARGE_BAS)
	_conteneur.alignment     = BoxContainer.ALIGNMENT_CENTER
	add_child(_conteneur)


# =======================================================
# RAFRAICHISSEMENT
# -------------------------------------------------------
# Appelée par main.gd à chaque changement de tour ou
# de sélection. Reconstruit toutes les cards.
# =======================================================
func rafraichir() -> void:
	# Vide le conteneur avant de reconstruire
	for enfant in _conteneur.get_children():
		enfant.queue_free()

	# Rien à afficher si pas de joueur actif ou pas de sorts
	if joueur_actif == null or joueur_actif.sorts.is_empty():
		return

	# Crée une card pour chacun des 4 sorts
	for i in range(joueur_actif.sorts.size()):
		var sort : Resource = joueur_actif.sorts[i]
		var card : PanelContainer = _creer_card(i, sort)
		_conteneur.add_child(card)


# =======================================================
# CRÉATION D'UNE CARD
# =======================================================

# -------------------------------------------------------
# Construit le PanelContainer d'une card avec son contenu.
# L'index détermine le raccourci clavier affiché (A/Z/E/R).
# -------------------------------------------------------
func _creer_card(index: int, sort: Resource) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_LARGEUR, CARD_HAUTEUR)

	# Détermine l'état de la card pour choisir sa couleur
	var etat    : String = _get_etat_sort(index, sort)
	var couleur : Color  = _get_couleur_etat(etat, index)

	# Applique le fond coloré via StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color              = couleur
	style.border_width_left     = 2
	style.border_width_right    = 2
	style.border_width_top      = 2
	style.border_width_bottom   = 2
	style.border_color          = COULEUR_BORDURE_SEL if etat == "selectionne" else Color(0.4, 0.4, 0.5, 0.8)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)

	# Contenu de la card (VBoxContainer)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	# Raccourci clavier + nom du sort
	var touches    : Array = ["A", "Z", "E", "R"]
	var label_nom  := Label.new()
	label_nom.text = "[%s] %s" % [touches[index], sort.nom]
	label_nom.add_theme_font_size_override("font_size", 14)
	label_nom.add_theme_color_override("font_color",
		Color.WHITE if etat != "verouille" else Color(0.5, 0.5, 0.5))
	label_nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label_nom)

	# Séparateur visuel
	vbox.add_child(HSeparator.new())

	# Description courte
	var label_desc := Label.new()
	label_desc.text          = sort.description
	label_desc.add_theme_font_size_override("font_size", 14)
	label_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	label_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label_desc)

	# Stats : PM | Gold | Dégâts | Portée
	var label_stats := Label.new()
	label_stats.text = _formater_stats(sort)
	label_stats.add_theme_font_size_override("font_size", 11)
	label_stats.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(label_stats)

	# Message d'état spécial (cooldown, verrouillé, PM insuffisants)
	var label_etat := Label.new()
	label_etat.text                    = _formater_etat(etat, sort)
	label_etat.add_theme_font_size_override("font_size", 11)
	label_etat.add_theme_color_override("font_color", _get_couleur_texte_etat(etat))
	label_etat.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label_etat)

	# Rend la card cliquable uniquement si le sort est utilisable
	if etat == "disponible" or etat == "selectionne":
		_rendre_cliquable(card, index)

	return card


# -------------------------------------------------------
# Détermine l'état d'un sort selon :
#   - Son index vs sorts_debloques (verrouillé ?)
#   - Son cooldown (en recharge ?)
#   - Les PM du joueur (insuffisants ?)
#   - L'index sélectionné dans input_handler
# -------------------------------------------------------
func _get_etat_sort(index: int, sort: Resource) -> String:
	# Sort non encore débloqué ce tour
	if index >= joueur_actif.sorts_debloques:
		return "verouille"

	# Sort sélectionné actuellement
	if input_handler != null and input_handler.sort_selectionne == index:
		return "selectionne"

	# Sort en cooldown
	if not sort.est_disponible():
		return "cooldown"

	# PM insuffisants pour lancer ce sort
	if joueur_actif.pm_actuels < sort.cout_pm:
		return "pm_insuffisants"

	return "disponible"


func _get_couleur_etat(etat: String, _index: int) -> Color:
	match etat:
		"selectionne":     return COULEUR_SELECTIONNE
		"cooldown":        return COULEUR_COOLDOWN
		"verouille":       return COULEUR_VEROUILLE
		"pm_insuffisants": return COULEUR_PM_INSUF
	return COULEUR_DISPONIBLE


func _get_couleur_texte_etat(etat: String) -> Color:
	match etat:
		"cooldown":        return Color(1.0, 0.6, 0.1)
		"verouille":       return Color(0.4, 0.4, 0.4)
		"pm_insuffisants": return Color(1.0, 0.3, 0.3)
		"selectionne":     return Color(0.8, 0.5, 1.0)
	return Color.TRANSPARENT


func _formater_stats(sort: Resource) -> String:
	var parties : Array = []
	parties.append("⚡ %d PM" % sort.cout_pm)
	if sort.cout_gold > 0:
		parties.append("💰 %d G" % sort.cout_gold)
	if sort.degats > 0:
		parties.append("⚔️ %d dmg" % sort.degats)
	if sort.portee > 0:
		parties.append("🎯 portée %d" % sort.portee)
	elif sort.portee == 0:
		parties.append("🎯 portée ∞")
	return "  ".join(parties)


func _formater_etat(etat: String, sort: Resource) -> String:
	match etat:
		"cooldown":        return "⏳ %d tour(s)" % sort.cooldown_actuel
		"verouille":       return "🔒 Verrouillé"
		"pm_insuffisants": return "❌ PM insuffisants"
		"selectionne":     return "✨ Sélectionné"
	return ""


# -------------------------------------------------------
# Ajoute un Button invisible par-dessus la card pour
# capturer les clics sans modifier son apparence.
# -------------------------------------------------------
func _rendre_cliquable(card: PanelContainer, index: int) -> void:
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Connecte le clic au handler de sélection
	btn.pressed.connect(_on_sort_clique.bind(index))
	card.add_child(btn)


# =======================================================
# GESTION DU CLIC
# =======================================================

# -------------------------------------------------------
# Clic sur une card de sort.
# Même logique que les touches A/Z/E/R dans input_handler :
#   - Si le sort est déjà sélectionné → désélectionne
#   - Sinon → sélectionne ce sort
# Puis rafraichit le renderer et la SortUI.
# -------------------------------------------------------
func _on_sort_clique(index: int) -> void:
	if input_handler == null:
		return

	# Toggle : reclique sur le même sort = désélection
	if input_handler.sort_selectionne == index:
		input_handler.sort_selectionne = -1
	else:
		input_handler.sort_selectionne = index

	# Met à jour les surbrillances 3D
	if renderer != null:
		renderer.sort_selectionne = input_handler.sort_selectionne
		renderer.rafraichir()

	# Rafraichit les cards pour refléter la nouvelle sélection
	rafraichir()
