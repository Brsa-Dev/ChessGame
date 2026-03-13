# =======================================================
# UI/inventory_ui.gd
# -------------------------------------------------------
# Inventaire du joueur actif — toggle via touche F.
# Construit entièrement en code (pas de .tscn associé).
#
#   - Affiche tous les items de l'inventaire du joueur
#   - Boutons d'utilisation pour les items manuels
#     (Bombe, Bandage, Flèches Empoisonnées, Cape de Forêt)
#   - Émet des signaux vers input_handler pour chaque utilisation
#
# NE gère PAS la logique d'application des items.
# =======================================================
extends CanvasLayer


# =======================================================
# SIGNAUX
# -------------------------------------------------------
# Connectés à input_handler dans main.gd._connecter_signaux().
# =======================================================

signal bombe_demande_cible(item: Resource)    # Active le mode ciblage bombe
signal bandage_utilise(item: Resource)        # Applique le bandage immédiatement
signal fleches_utilisees(item: Resource)      # Active le flag flèches empoisonnées
signal cape_utilisee(item: Resource)          # Active le mode ciblage cape de forêt


# =======================================================
# COULEURS DES ITEMS PAR CLASSE
# Alignées avec hud_ui.gd
# =======================================================

const COULEUR_COMMUN  : String = "#ffffff"
const COULEUR_GUERRIER: String = "#ff6644"
const COULEUR_MAGE    : String = "#aa66ff"
const COULEUR_ARCHER  : String = "#44ff88"
const COULEUR_FRIPON  : String = "#ffdd44"


# =======================================================
# ÉTAT
# =======================================================

var _joueur_actif : Node  = null   # Joueur dont l'inventaire est affiché
var _visible      : bool  = false  # État du panneau (ouvert/fermé)


# =======================================================
# NŒUDS — Construits dans _ready()
# =======================================================

var _panel : PanelContainer = null
var _vbox  : VBoxContainer  = null


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	_construire_panel()


# -------------------------------------------------------
# Construit le panneau et son titre une seule fois.
# Le contenu (liste des items) est reconstruit à chaque toggle.
# -------------------------------------------------------
func _construire_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false

	var taille : Vector2 = get_viewport().get_visible_rect().size
	_panel.set_position(Vector2(taille.x / 2.0 - 200, taille.y / 2.0 - 250))
	_panel.set_size(Vector2(400, 500))
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_vbox)

	var titre : Label = Label.new()
	titre.text = "🎒 Inventaire"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_color_override("font_color", Color.WHITE)
	_vbox.add_child(titre)

	_vbox.add_child(HSeparator.new())


# =======================================================
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Ouvre ou ferme l'inventaire.
# Appelée par input_handler à la touche F.
# -------------------------------------------------------
func toggle(joueur: Node) -> void:
	_joueur_actif = joueur
	_visible      = not _visible
	_panel.visible = _visible

	if _visible:
		_rafraichir()


# =======================================================
# AFFICHAGE
# =======================================================

# -------------------------------------------------------
# Reconstruit la liste des items à chaque ouverture.
# Supprime les entrées précédentes (sauf titre + séparateur).
# -------------------------------------------------------
func _rafraichir() -> void:
	# Supprime tout sauf le titre (index 0) et le séparateur (index 1)
	while _vbox.get_child_count() > 2:
		var enfant : Node = _vbox.get_child(_vbox.get_child_count() - 1)
		_vbox.remove_child(enfant)
		enfant.queue_free()

	if _joueur_actif == null:
		return

	if _joueur_actif.inventaire.is_empty():
		var label_vide : Label = Label.new()
		label_vide.text = "Inventaire vide"
		label_vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_vide.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_vbox.add_child(label_vide)
	else:
		for item in _joueur_actif.inventaire:
			_vbox.add_child(_creer_ligne_item(item))

	# Bouton Fermer toujours en bas
	var btn_fermer : Button = Button.new()
	btn_fermer.text = "Fermer"
	btn_fermer.pressed.connect(func() -> void:
		_panel.visible = false
		_visible       = false
	)
	_vbox.add_child(btn_fermer)


# -------------------------------------------------------
# Crée une ligne HBox pour un item :
# [RichTextLabel nom+description] [Bouton d'utilisation (si applicable)]
# -------------------------------------------------------
func _creer_ligne_item(item: Resource) -> HBoxContainer:
	var hbox : HBoxContainer = HBoxContainer.new()

	# Couleur selon la classe requise
	var couleur : String = _get_couleur_classe(item.classe_requise)

	var rtl : RichTextLabel = RichTextLabel.new()
	rtl.bbcode_enabled  = true
	rtl.fit_content     = true
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.custom_minimum_size   = Vector2(280, 0)
	rtl.text = "[color=%s][b]%s[/b][/color]  [color=#888888]%s[/color]" % [
		couleur, item.nom, item.description
	]
	hbox.add_child(rtl)

	# Bouton d'utilisation — uniquement pour les items actifs manuels
	var bouton : Button = _creer_bouton_utilisation(item)
	if bouton != null:
		hbox.add_child(bouton)

	return hbox


# -------------------------------------------------------
# Crée le bouton d'utilisation pour les items manuels.
# Retourne null si l'item n'a pas de bouton (passif ou permanent).
# -------------------------------------------------------
func _creer_bouton_utilisation(item: Resource) -> Button:
	match item.id:

		"bombe":
			var btn : Button = _creer_bouton("💣 Lancer", 90)
			btn.pressed.connect(func() -> void:
				_fermer()
				emit_signal("bombe_demande_cible", item)
			)
			return btn

		"bandage":
			var btn : Button = _creer_bouton("🩹 Utiliser", 90)
			btn.pressed.connect(func() -> void:
				_fermer()
				emit_signal("bandage_utilise", item)
			)
			return btn

		"fleches_empoisonnees":
			var btn : Button = _creer_bouton("🏹 Activer", 90)
			btn.pressed.connect(func() -> void:
				_fermer()
				emit_signal("fleches_utilisees", item)
			)
			return btn

		"cape_foret":
			var charges : int    = _joueur_actif.cape_foret_charges
			var btn     : Button = _creer_bouton("🌲 Utiliser (%d)" % charges, 110)
			btn.disabled = (charges <= 0)
			btn.pressed.connect(func() -> void:
				_fermer()
				emit_signal("cape_utilisee", item)
			)
			return btn

	return null  # Pas de bouton pour cet item


# -------------------------------------------------------
# Crée un bouton avec la taille minimale spécifiée
# -------------------------------------------------------
func _creer_bouton(texte: String, largeur_min: int) -> Button:
	var btn : Button = Button.new()
	btn.text                = texte
	btn.custom_minimum_size = Vector2(largeur_min, 0)
	return btn


# -------------------------------------------------------
# Retourne la couleur BBCode selon la classe requise de l'item
# -------------------------------------------------------
func _get_couleur_classe(classe: String) -> String:
	match classe:
		"guerrier": return COULEUR_GUERRIER
		"mage":     return COULEUR_MAGE
		"archer":   return COULEUR_ARCHER
		"fripon":   return COULEUR_FRIPON
	return COULEUR_COMMUN


# -------------------------------------------------------
# Ferme le panneau
# -------------------------------------------------------
func _fermer() -> void:
	_panel.visible = false
	_visible       = false
