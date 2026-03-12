# shop_ui.gd
# -----------------------------------------------
# SHOP UI — Interface visuelle de la boutique
# Affiche les items, gère les clics d'achat
# Communique avec shop_manager.gd pour la logique
# -----------------------------------------------
extends CanvasLayer

# Référence au shop_manager (assignée par main.gd)
var shop_manager: Node = null

# Le joueur qui est en train d'acheter
var joueur_actif: Node = null

# -----------------------------------------------
# Nœuds de l'interface (assignés dans _ready)
# -----------------------------------------------

@onready var panneau         = $Panneau
@onready var label_titre     = $Panneau/VBoxContainer/Titre
@onready var label_gold      = $Panneau/VBoxContainer/Gold
@onready var conteneur_items = $Panneau/VBoxContainer/Items
@onready var bouton_passer   = $Panneau/VBoxContainer/BoutonPasser

# Signal émis quand le joueur a terminé ses achats
signal boutique_fermee

# -----------------------------------------------
# Initialisation — on cache la boutique au démarrage
# -----------------------------------------------
func _ready():
	panneau.visible = false
	bouton_passer.pressed.connect(_on_passer)

# -----------------------------------------------
# Ouvre la boutique pour un joueur donné
# Appelée par main.gd
# -----------------------------------------------
func ouvrir(joueur: Node):
	joueur_actif = joueur
	panneau.visible = true
	
	# Titre avec le numéro du joueur
	label_titre.text = "🛒 Boutique — Joueur %s" % joueur.name
	
	# Affiche le gold actuel du joueur
	_rafraichir_gold()
	
	# Génère un bouton par item dans le stock
	_afficher_items()
	
	print("Boutique ouverte pour : ", joueur.name)

# -----------------------------------------------
# Met à jour l'affichage du gold
# -----------------------------------------------
func _rafraichir_gold():
	label_gold.text = "💰 Gold : %d" % joueur_actif.gold

# -----------------------------------------------
# Génère dynamiquement les boutons d'items
# On vide d'abord le conteneur pour éviter les doublons
# -----------------------------------------------
func _afficher_items():
	# Supprime les anciens boutons
	for enfant in conteneur_items.get_children():
		enfant.queue_free()
	
	# Crée un bouton pour chaque item du stock
	for item in shop_manager.stock:
		var bouton = Button.new()
		
		# Texte du bouton : nom + prix + description
		bouton.text = "%s — %d Gold\n%s" % [item.nom, item.prix, item.description]
		bouton.autowrap_mode = TextServer.AUTOWRAP_WORD
		bouton.custom_minimum_size = Vector2(300, 60)
		
		# Grise le bouton si le joueur ne peut pas acheter
		bouton.disabled = not shop_manager.peut_acheter(joueur_actif, item)
		
		# Connecte le clic — on passe l'item en paramètre
		bouton.pressed.connect(_on_acheter.bind(item))
		
		conteneur_items.add_child(bouton)

# -----------------------------------------------
# Appelée quand le joueur clique sur un item
# -----------------------------------------------
func _on_acheter(item: Resource):
	shop_manager.acheter(joueur_actif, item)
	
	# On rafraîchit l'affichage après l'achat
	_rafraichir_gold()
	_afficher_items()  # Remet à jour les boutons (grisés si plus assez de gold)

# -----------------------------------------------
# Appelée quand le joueur clique "Passer"
# -----------------------------------------------
func _on_passer():
	panneau.visible = false
	print("Joueur ", joueur_actif.name, " passe la boutique")
	emit_signal("boutique_fermee")
