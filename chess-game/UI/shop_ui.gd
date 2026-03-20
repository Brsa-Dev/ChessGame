# =======================================================
# UI/shop_ui.gd
# -------------------------------------------------------
# Affichage de la boutique — NE contient PAS de logique d'achat.
#
#   - Affiche les items disponibles pour le joueur actif
#   - Grise les boutons si le joueur ne peut pas acheter
#   - Émet boutique_fermee quand le joueur passe ou achète tout
#
# La logique d'achat et les effets sont dans shop_manager.gd.
# =======================================================
extends CanvasLayer


# =======================================================
# SIGNAUX
# =======================================================

# Émis quand le joueur clique "Passer" — main.gd passe au joueur suivant
signal boutique_fermee


# =======================================================
# RÉFÉRENCES — Nœuds de la scène (définis dans shop_ui.tscn)
# =======================================================

@onready var _panneau         : PanelContainer = $Panneau
@onready var _label_titre     : Label          = $Panneau/VBoxContainer/Titre
@onready var _label_gold      : Label          = $Panneau/VBoxContainer/Gold
@onready var _conteneur_items : VBoxContainer  = $Panneau/VBoxContainer/Items
@onready var _bouton_passer   : Button         = $Panneau/VBoxContainer/BoutonPasser


# =======================================================
# RÉFÉRENCES — Injectées par main.gd
# =======================================================

var shop_manager : Node = null


# =======================================================
# ÉTAT
# =======================================================

var _joueur_actif : Node = null  # Joueur en train d'acheter


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	_panneau.visible = false
	_bouton_passer.pressed.connect(_on_passer)


# =======================================================
# API PUBLIQUE
# =======================================================

# -------------------------------------------------------
# Ouvre la boutique pour un joueur donné.
# Appelée par main.gd dans _on_phase_boutique().
# -------------------------------------------------------
func ouvrir(joueur: Node) -> void:
	_joueur_actif    = joueur
	_panneau.visible = true

	_label_titre.text = "🛒 Boutique — %s" % joueur.name
	_rafraichir_gold()
	_afficher_items()


# =======================================================
# AFFICHAGE
# =======================================================

func _rafraichir_gold() -> void:
	_label_gold.text = "💰 Gold : %d" % _joueur_actif.gold


# -------------------------------------------------------
# Reconstruit les boutons d'items à chaque rafraîchissement.
# Filtre les items par classe du joueur via shop_manager.
# -------------------------------------------------------
func _afficher_items() -> void:
	for enfant in _conteneur_items.get_children():
		enfant.queue_free()

	var items_visibles : Array[Item] = shop_manager.get_stock_pour_joueur(_joueur_actif)

	for item in items_visibles:
		var bouton : Button = Button.new()

		var prefix : String = "" if item.classe_requise == "" else "[%s] " % item.classe_requise.capitalize()
		bouton.text                = "%s%s — %d Gold\n%s" % [prefix, item.nom, item.prix, item.description]
		bouton.autowrap_mode       = TextServer.AUTOWRAP_WORD
		bouton.custom_minimum_size = Vector2(300, 60)
		bouton.disabled            = not shop_manager.peut_acheter(_joueur_actif, item)
		bouton.pressed.connect(_on_acheter.bind(item))
		_conteneur_items.add_child(bouton)


# =======================================================
# CALLBACKS
# =======================================================

func _on_acheter(item: Item) -> void:
	shop_manager.acheter(_joueur_actif, item)
	_rafraichir_gold()
	_afficher_items()


func _on_passer() -> void:
	_panneau.visible = false
	boutique_fermee.emit()
