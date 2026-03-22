# =======================================================
# UI/lobby_ui.gd
# -------------------------------------------------------
# Responsabilité : interface de pré-partie.
#
# Phases :
#   A — Connexion     : Host crée, Client rejoint
#   B — Sélection     : équipe (Rouge/Bleue) + classe
#   C — Mode          : format 1v1/2v2/3v3 (Host uniquement)
#
# Émet partie_lancee(configs) quand tous sont prêts.
# NE contient PAS de logique réseau (tout dans NetworkManager).
# =======================================================
extends CanvasLayer


# =======================================================
# SIGNAUX
# =======================================================

## Émis quand la partie peut démarrer.
## @param configs : Array de Dictionary {peer_id, classe, equipe, est_roi}
signal partie_lancee(configs: Array)


# =======================================================
# CONSTANTES — Layout
# =======================================================

const LARGEUR_PANEL : int = 500
const HAUTEUR_PANEL : int = 520
const ESPACEMENT    : int = 12


# =======================================================
# CONSTANTES — Données de jeu
# =======================================================

## Classes disponibles à la sélection.
const CLASSES_DISPONIBLES : Array[String] = ["Guerrier", "Mage", "Archer", "Fripon"]

## Équipes disponibles. Clé = nom affiché, valeur = index int.
const EQUIPES : Dictionary = { "🔴 Rouge": 0, "🔵 Bleue": 1 }


# =======================================================
# PHASES DU LOBBY
# =======================================================

enum Phase { CONNEXION, SELECTION, MODE, ATTENTE }
var _phase : Phase = Phase.CONNEXION


# =======================================================
# ÉTAT LOCAL
# =======================================================

var _equipe_choisie : int    = -1  # -1 = pas encore choisi
var _classe_choisie : String = ""  # "" = pas encore choisi
var _mode_choisi    : String = ""  # "" = pas encore choisi


# =======================================================
# RÉFÉRENCES UI
# =======================================================

var _fond            : ColorRect
var _panel_connexion : PanelContainer
var _panel_selection : PanelContainer
var _panel_mode      : PanelContainer
var _label_statut    : Label
var _champ_ip        : LineEdit
var _btn_host        : Button
var _btn_rejoindre   : Button
var _btn_deconnecter : Button
var _btns_equipe     : Dictionary = {}  # nom → Button
var _btns_classe     : Dictionary = {}  # nom → Button
var _btn_confirmer   : Button
var _label_erreur    : Label
var _liste_joueurs   : VBoxContainer   # Affichage temps réel des choix
var _btns_mode       : Dictionary = {}  # "1v1"/"2v2"/"3v3" → Button
var _btn_lancer      : Button


# =======================================================
# INITIALISATION
# =======================================================

func _ready() -> void:
	layer = 100  # Au-dessus de tous les autres CanvasLayers du jeu
	_construire_fond()
	_construire_panel_connexion()
	_construire_panel_selection()
	_construire_panel_mode()
	_afficher_phase(Phase.CONNEXION)
	_connecter_signaux_reseau()


# =======================================================
# CONSTRUCTION UI — Fond bloquant
# =======================================================

## Crée un fond semi-opaque plein écran qui capture tous les clics.
## Sans ça, les clics sur le lobby traversent vers le plateau.
func _construire_fond() -> void:
	_fond = ColorRect.new()
	_fond.color = Color(0.0, 0.0, 0.0, 0.85)
	_fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fond)


# =======================================================
# CONSTRUCTION UI — Phase A : Connexion
# =======================================================

func _construire_panel_connexion() -> void:
	var centre := _creer_centre()
	_panel_connexion = _creer_panel(LARGEUR_PANEL, 340)
	centre.add_child(_panel_connexion)

	var vbox := _creer_vbox(_panel_connexion)

	_ajouter_titre(vbox, "⚔️  Multijoueur — Connexion")
	vbox.add_child(HSeparator.new())

	var label_ip := Label.new()
	label_ip.text = "IP du Host :"
	vbox.add_child(label_ip)

	_champ_ip = LineEdit.new()
	_champ_ip.placeholder_text    = "127.0.0.1"
	_champ_ip.text                = "127.0.0.1"
	_champ_ip.custom_minimum_size = Vector2(0, 38)
	vbox.add_child(_champ_ip)

	_btn_host = _creer_bouton("🖥️  Héberger une partie", _on_btn_host)
	vbox.add_child(_btn_host)

	_btn_rejoindre = _creer_bouton("🌐  Rejoindre la partie", _on_btn_rejoindre)
	vbox.add_child(_btn_rejoindre)

	_btn_deconnecter = _creer_bouton("❌  Annuler", _on_btn_deconnecter)
	_btn_deconnecter.visible = false
	vbox.add_child(_btn_deconnecter)

	_label_statut = Label.new()
	_label_statut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_statut.add_theme_font_size_override("font_size", 13)
	_label_statut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_label_statut)
	_set_statut("Choisissez une option.", Color.GRAY)


# =======================================================
# CONSTRUCTION UI — Phase B : Sélection équipe + classe
# =======================================================

func _construire_panel_selection() -> void:
	var centre := _creer_centre()
	_panel_selection = _creer_panel(LARGEUR_PANEL, HAUTEUR_PANEL)
	centre.add_child(_panel_selection)

	var vbox := _creer_vbox(_panel_selection)

	_ajouter_titre(vbox, "⚔️  Choix de l'équipe et de la classe")
	vbox.add_child(HSeparator.new())

	## Boutons d'équipe
	var label_eq := Label.new()
	label_eq.text = "Ton équipe :"
	vbox.add_child(label_eq)

	var hbox_eq := HBoxContainer.new()
	hbox_eq.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox_eq)

	for nom_equipe in EQUIPES:
		var btn := _creer_bouton(nom_equipe, _on_equipe_choisie.bind(EQUIPES[nom_equipe]))
		btn.custom_minimum_size = Vector2(160, 45)
		hbox_eq.add_child(btn)
		_btns_equipe[nom_equipe] = btn

	vbox.add_child(HSeparator.new())

	## Boutons de classe
	var label_cl := Label.new()
	label_cl.text = "Ta classe :"
	vbox.add_child(label_cl)

	var hbox_cl := HBoxContainer.new()
	hbox_cl.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox_cl)

	for classe in CLASSES_DISPONIBLES:
		var btn := _creer_bouton(classe, _on_classe_choisie.bind(classe))
		btn.custom_minimum_size = Vector2(100, 45)
		hbox_cl.add_child(btn)
		_btns_classe[classe] = btn

	## Message d'erreur
	_label_erreur = Label.new()
	_label_erreur.text = ""
	_label_erreur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_erreur.add_theme_color_override("font_color", Color.RED)
	vbox.add_child(_label_erreur)

	vbox.add_child(HSeparator.new())

	## Liste des joueurs connectés
	var label_joueurs := Label.new()
	label_joueurs.text = "Joueurs connectés :"
	label_joueurs.add_theme_font_size_override("font_size", 12)
	vbox.add_child(label_joueurs)

	_liste_joueurs = VBoxContainer.new()
	_liste_joueurs.add_theme_constant_override("separation", 4)
	vbox.add_child(_liste_joueurs)

	vbox.add_child(HSeparator.new())

	_btn_confirmer          = _creer_bouton("✅  Confirmer", _on_btn_confirmer)
	_btn_confirmer.disabled = true
	vbox.add_child(_btn_confirmer)


# =======================================================
# CONSTRUCTION UI — Phase C : Choix du mode (Host only)
# =======================================================

func _construire_panel_mode() -> void:
	var centre := _creer_centre()
	_panel_mode = _creer_panel(LARGEUR_PANEL, 260)
	centre.add_child(_panel_mode)

	var vbox := _creer_vbox(_panel_mode)
	_ajouter_titre(vbox, "⚔️  Choix du mode de jeu")
	vbox.add_child(HSeparator.new())

	var label := Label.new()
	label.text = "Format de la partie (Host uniquement) :"
	vbox.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	for format in NetworkManager.FORMATS_JEU:
		var nb  : int    = NetworkManager.FORMATS_JEU[format]
		var btn : Button = _creer_bouton(
			"%s (%d joueurs)" % [format, nb],
			_on_mode_choisi.bind(format)
		)
		btn.custom_minimum_size = Vector2(130, 50)
		hbox.add_child(btn)
		_btns_mode[format] = btn

	vbox.add_child(HSeparator.new())

	_btn_lancer          = _creer_bouton("🚀  Lancer la partie", _on_btn_lancer)
	_btn_lancer.disabled = true
	vbox.add_child(_btn_lancer)


# =======================================================
# AFFICHAGE DES PHASES
# =======================================================

## Affiche uniquement le panel de la phase demandée.
func _afficher_phase(phase: Phase) -> void:
	_phase = phase
	_panel_connexion.visible = (phase == Phase.CONNEXION)
	_panel_selection.visible = (phase == Phase.SELECTION)
	_panel_mode.visible      = (phase == Phase.MODE)


# =======================================================
# CONNEXION DES SIGNAUX RÉSEAU
# =======================================================

func _connecter_signaux_reseau() -> void:
	NetworkManager.connexion_reussie.connect(_on_connexion_reussie)
	NetworkManager.connexion_echouee.connect(_on_connexion_echouee)
	NetworkManager.tous_connectes.connect(_on_tous_connectes)
	NetworkManager.choix_mis_a_jour.connect(_on_choix_mis_a_jour)
	NetworkManager.choix_refuse.connect(_on_choix_refuse)
	NetworkManager.tous_prets.connect(_on_tous_prets)


# =======================================================
# HANDLERS — Phase A : Connexion
# =======================================================

func _on_btn_host() -> void:
	print("[LOBBY] _on_btn_host appelé")
	_set_statut("⏳ Démarrage du serveur...", Color.YELLOW)
	_btn_host.disabled       = true
	_btn_rejoindre.disabled  = true
	_btn_deconnecter.visible = true
	## Démarre sans format — le format sera choisi en Phase C
	NetworkManager.demarrer_host()
	## Passe en Phase C pour que le Host choisisse le format
	_afficher_phase(Phase.MODE)


func _on_btn_rejoindre() -> void:
	var ip : String = _champ_ip.text.strip_edges()
	if ip.is_empty():
		_set_statut("❌ IP invalide.", Color.RED)
		return
	_set_statut("⏳ Connexion vers %s..." % ip, Color.YELLOW)
	_btn_host.disabled       = true
	_btn_rejoindre.disabled  = true
	_btn_deconnecter.visible = true
	NetworkManager.rejoindre_partie(ip)


func _on_btn_deconnecter() -> void:
	NetworkManager.deconnecter()
	_btn_host.disabled       = false
	_btn_rejoindre.disabled  = false
	_btn_deconnecter.visible = false
	_afficher_phase(Phase.CONNEXION)
	_set_statut("Déconnecté.", Color.GRAY)


func _on_connexion_reussie() -> void:
	_set_statut("✅ Connecté ! En attente des autres joueurs...", Color.GREEN)


func _on_connexion_echouee() -> void:
	_set_statut("❌ Connexion échouée.", Color.RED)
	_btn_host.disabled       = false
	_btn_rejoindre.disabled  = false
	_btn_deconnecter.visible = false
	_afficher_phase(Phase.CONNEXION)


func _on_tous_connectes() -> void:
	_afficher_phase(Phase.SELECTION)
	_rafraichir_liste_joueurs()


# =======================================================
# HANDLERS — Phase B : Sélection équipe + classe
# =======================================================

func _on_equipe_choisie(equipe: int) -> void:
	_equipe_choisie = equipe
	for nom in _btns_equipe:
		_btns_equipe[nom].modulate = Color.YELLOW if EQUIPES[nom] == equipe else Color.WHITE
	_mettre_a_jour_btn_confirmer()


func _on_classe_choisie(classe: String) -> void:
	_classe_choisie = classe
	for nom in _btns_classe:
		_btns_classe[nom].modulate = Color.YELLOW if nom == classe else Color.WHITE
	_mettre_a_jour_btn_confirmer()


func _on_btn_confirmer() -> void:
	_label_erreur.text      = ""
	_btn_confirmer.disabled = true

	if NetworkManager.est_host():
		## Le Host traite son propre choix directement
		## (rpc_id vers soi-même n'est pas fiable dans Godot 4)
		var mon_id : int = NetworkManager.get_mon_id()
		for id in NetworkManager.choix_joueurs:
			if id == mon_id:
				continue
			var c : Dictionary = NetworkManager.choix_joueurs[id]
			if c.get("equipe", -1) == _equipe_choisie and c.get("classe", "") == _classe_choisie:
				_label_erreur.text      = "❌ Classe déjà prise dans cette équipe !"
				_btn_confirmer.disabled = false
				return
		NetworkManager.choix_joueurs[mon_id].equipe = _equipe_choisie
		NetworkManager.choix_joueurs[mon_id].classe = _classe_choisie
		NetworkManager.choix_joueurs[mon_id].pret   = true
		NetworkManager.rpc_sync_choix.rpc(mon_id, _equipe_choisie, _classe_choisie)
		NetworkManager._verifier_tous_prets()
	else:
		## Client → envoie au Host
		NetworkManager.rpc_soumettre_choix.rpc_id(1, _equipe_choisie, _classe_choisie)
		NetworkManager.rpc_confirmer_pret.rpc_id(1)


func _on_choix_mis_a_jour(_peer_id: int) -> void:
	_rafraichir_liste_joueurs()


func _on_choix_refuse(raison: String) -> void:
	_label_erreur.text      = "❌ %s" % raison
	_btn_confirmer.disabled = false


# =======================================================
# HANDLERS — Phase C : Mode
# =======================================================

func _on_mode_choisi(format: String) -> void:
	_mode_choisi = format
	for f in _btns_mode:
		_btns_mode[f].modulate = Color.YELLOW if f == format else Color.WHITE
	_btn_lancer.disabled = false


func _on_btn_lancer() -> void:
	if _mode_choisi.is_empty():
		return
	## Met à jour le nombre de joueurs attendus selon le format choisi
	NetworkManager.joueurs_attendus = NetworkManager.FORMATS_JEU[_mode_choisi]
	## Informe tous les clients déjà connectés du nouveau format
	NetworkManager.rpc_definir_joueurs_attendus.rpc(NetworkManager.joueurs_attendus)
	_afficher_phase(Phase.SELECTION)
	_rafraichir_liste_joueurs()


func _on_tous_prets(configs: Array) -> void:
	await get_tree().create_timer(0.5).timeout
	visible = false
	partie_lancee.emit(configs)


# =======================================================
# HANDLERS — Utilitaires
# =======================================================

## Met à jour le bouton Confirmer — actif seulement si équipe ET classe choisis.
func _mettre_a_jour_btn_confirmer() -> void:
	_btn_confirmer.disabled = (_equipe_choisie == -1 or _classe_choisie.is_empty())


## Reconstruit la liste visuelle des choix de tous les joueurs.
func _rafraichir_liste_joueurs() -> void:
	for enfant in _liste_joueurs.get_children():
		enfant.queue_free()
	for peer_id in NetworkManager.choix_joueurs:
		var c      : Dictionary = NetworkManager.choix_joueurs[peer_id]
		var label  : Label      = Label.new()
		var equipe : String     = "🔴 Rouge" if c.get("equipe", -1) == 0 else "🔵 Bleue"
		var classe : String     = c.get("classe", "?") if c.get("classe", "") != "" else "?"
		var pret   : String     = "✅" if c.get("pret", false) else "⏳"
		var moi    : String     = " (moi)" if peer_id == NetworkManager.get_mon_id() else ""
		label.text = "%s Peer %d%s — %s — %s" % [pret, peer_id, moi, equipe, classe]
		label.add_theme_font_size_override("font_size", 12)
		_liste_joueurs.add_child(label)


# =======================================================
# HELPERS PRIVÉS — Constructeurs UI factorisés
# =======================================================

## Crée un CenterContainer plein écran.
func _creer_centre() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


## Crée un PanelContainer avec taille minimale.
func _creer_panel(largeur: int, hauteur: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(largeur, hauteur)
	p.mouse_filter        = Control.MOUSE_FILTER_STOP
	return p


## Crée un VBoxContainer centré avec espacement standard.
func _creer_vbox(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", ESPACEMENT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(v)
	return v


## Ajoute un label titre centré dans le parent.
func _ajouter_titre(parent: Control, texte: String) -> void:
	var l := Label.new()
	l.text                  = texte
	l.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 17)
	parent.add_child(l)


## Crée un bouton avec texte et callback.
func _creer_bouton(texte: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text                = texte
	btn.custom_minimum_size = Vector2(0, 42)
	btn.pressed.connect(callback)
	return btn


## Met à jour le label de statut (Phase A).
func _set_statut(texte: String, couleur: Color) -> void:
	if _label_statut == null:
		return
	_label_statut.text = texte
	_label_statut.add_theme_color_override("font_color", couleur)
