# inventory_ui.gd
# -----------------------------------------------
# INVENTORY UI — Affiche les items possédés
# Ouvert/fermé avec la touche F (configurable)
# Construit entièrement en code
# -----------------------------------------------
extends CanvasLayer

# Référence au joueur actif — mise à jour par main.gd
var joueur_actif: Node = null

var _panel: PanelContainer = null
var _vbox: VBoxContainer = null
var _visible: bool = false

# -----------------------------------------------
# _ready — Construit l'UI en code
# -----------------------------------------------
func _ready():
	_panel = PanelContainer.new()
	_panel.visible = false

	# Centré dans la fenêtre
	var taille = get_viewport().get_visible_rect().size
	_panel.set_position(Vector2(taille.x / 2 - 200, taille.y / 2 - 250))
	_panel.set_size(Vector2(400, 500))
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(vbox)
	_vbox = vbox

	var titre = Label.new()
	titre.text = "🎒 Inventaire"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(titre)

	vbox.add_child(HSeparator.new())

# -----------------------------------------------
# toggle — Ouvre ou ferme l'inventaire
# Appelée par main.gd à la touche F
# -----------------------------------------------
func toggle(joueur: Node):
	joueur_actif = joueur
	_visible = not _visible
	_panel.visible = _visible

	if _visible:
		_rafraichir()

# -----------------------------------------------
# _rafraichir — Reconstruit la liste des items
# -----------------------------------------------
func _rafraichir():
	# Supprime les anciens labels (sauf titre et séparateur)
	while _vbox.get_child_count() > 2:
		var enfant = _vbox.get_child(_vbox.get_child_count() - 1)
		_vbox.remove_child(enfant)
		enfant.queue_free()

	if joueur_actif == null:
		return

	# Affiche chaque item de l'inventaire
	if joueur_actif.inventaire.is_empty():
		var label_vide = Label.new()
		label_vide.text = "Inventaire vide"
		label_vide.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		label_vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vbox.add_child(label_vide)
		return

	for item in joueur_actif.inventaire:
		var rtl = RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.custom_minimum_size = Vector2(380, 0)

		# Couleur selon la classe de l'item
		var couleur = "#ffffff"
		match item.classe_requise:
			"guerrier": couleur = "#ff6644"
			"mage":     couleur = "#aa66ff"
			"archer":   couleur = "#44ff88"
			"fripon":   couleur = "#ffdd44"

		rtl.text = "[color=" + couleur + "][b]" + item.nom + "[/b][/color]"
		rtl.text += "  [color=#888888]" + item.description + "[/color]"
		_vbox.add_child(rtl)

	# Bouton fermer
	var btn_fermer = Button.new()
	btn_fermer.text = "Fermer"
	btn_fermer.pressed.connect(func(): _panel.visible = false; _visible = false)
	_vbox.add_child(btn_fermer)
