# =======================================================
# Network/network_manager.gd
# -------------------------------------------------------
# Responsabilité UNIQUE : gérer la connexion ENet P2P.
#
#   - Héberger ou rejoindre une partie
#   - Maintenir la liste des peers connectés
#   - Stocker les choix de chaque joueur (équipe, classe)
#   - Synchroniser ces choix entre tous les peers
#   - Notifier via signaux (pas de logique de jeu ici)
#
# Scalable : fonctionne pour 2, 4 ou 6 joueurs.
# Ajouter un format = modifier FORMATS_JEU uniquement.
# =======================================================
extends Node


# =======================================================
# CONSTANTES
# =======================================================

## Port UDP d'écoute du Host.
## Doit être identique sur Host et Client.
const PORT        : int = 7777

## Maximum de clients autorisés à se connecter simultanément.
## 5 clients + 1 Host = 6 joueurs max (format 3v3).
const MAX_CLIENTS : int = 5

## Formats de jeu disponibles — clé = nom affiché, valeur = nb joueurs total.
## Ajouter un format = 1 ligne ici.
const FORMATS_JEU : Dictionary = {
	"1v1" : 2,
	"2v2" : 4,
	"3v3" : 6,
}

## Format par défaut utilisé si non précisé.
const FORMAT_DEFAUT : String = "1v1"


# =======================================================
# SIGNAUX
# =======================================================

## Connexion réussie côté Client.
signal connexion_reussie

## Échec de connexion côté Client.
signal connexion_echouee

## Un nouveau peer s'est connecté.
## @param peer_id : ID unique du peer
signal peer_connecte(peer_id: int)

## Un peer s'est déconnecté.
## @param peer_id : ID unique du peer
signal peer_deconnecte(peer_id: int)

## Tous les joueurs attendus sont connectés.
signal tous_connectes

## Un choix (équipe/classe) a été mis à jour.
## @param peer_id : ID du peer dont le choix a changé
signal choix_mis_a_jour(peer_id: int)

## Tous les joueurs ont confirmé leurs choix → prêts à lancer.
## @param configs : Array de Dictionary {peer_id, classe, equipe, est_roi}
signal tous_prets(configs: Array)

## Le Host a refusé un choix (classe déjà prise dans l'équipe).
## @param raison : message d'erreur
signal choix_refuse(raison: String)


# =======================================================
# ÉTAT
# =======================================================

## Nombre de joueurs attendus — défini par le Host selon le format.
## Mis à jour via rpc_definir_joueurs_attendus().
var joueurs_attendus : int = 0

## IDs de tous les peers connectés (Host inclus).
var peers_connectes : Array[int] = []

## Choix de chaque joueur.
## Clé = peer_id, Valeur = { classe, equipe, pret, est_roi }
var choix_joueurs : Dictionary = {}

## Tampon pour le plateau reçu (anti race-condition Phase 3).
## Stocke l'état du plateau si reçu avant que le signal soit connecté.
var _plateau_tampon      : Array = []
var _plateau_tampon_pret : bool  = false


# =======================================================
# INITIALISATION
# =======================================================
func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connexion_reussie)
	multiplayer.connection_failed.connect(_on_connexion_echouee)
	multiplayer.peer_connected.connect(_on_peer_connecte)
	multiplayer.peer_disconnected.connect(_on_peer_deconnecte)


# =======================================================
# API PUBLIQUE — Connexion
# =======================================================

## Démarre le jeu en tant que Host.
## @param format : clé de FORMATS_JEU ("1v1", "2v2" ou "3v3")
func demarrer_host(format: String = FORMAT_DEFAUT) -> void:
	var peer   := ENetMultiplayerPeer.new()
	var erreur := peer.create_server(PORT, MAX_CLIENTS)
	if erreur != OK:
		push_error("NetworkManager.demarrer_host : port %d indisponible" % PORT)
		return

	multiplayer.multiplayer_peer = peer
	joueurs_attendus             = FORMATS_JEU.get(format, FORMATS_JEU[FORMAT_DEFAUT])

	peers_connectes.append(get_mon_id())
	choix_joueurs[get_mon_id()] = _choix_vide()

	print("NetworkManager : Host démarré — port %d, format %s (%d joueurs)"
		% [PORT, format, joueurs_attendus])


## Tente de rejoindre une partie existante.
## @param ip : adresse IP du Host
func rejoindre_partie(ip: String) -> void:
	var peer   := ENetMultiplayerPeer.new()
	var erreur := peer.create_client(ip, PORT)
	if erreur != OK:
		push_error("NetworkManager.rejoindre_partie : connexion vers %s:%d échouée" % [ip, PORT])
		connexion_echouee.emit()
		return

	multiplayer.multiplayer_peer = peer
	print("NetworkManager : tentative de connexion vers %s:%d..." % [ip, PORT])


## Déconnecte proprement et remet tout à zéro.
func deconnecter() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	peers_connectes.clear()
	choix_joueurs.clear()
	joueurs_attendus     = 0
	_plateau_tampon      = []
	_plateau_tampon_pret = false

	print("NetworkManager : déconnecté.")


# =======================================================
# API PUBLIQUE — Accesseurs
# =======================================================

## Retourne l'ID du peer local.
func get_mon_id() -> int:
	return multiplayer.get_unique_id()

## Retourne true si le peer local est le Host.
func est_host() -> bool:
	return multiplayer.is_server()

## Retourne true si le réseau est actif.
func est_connecte() -> bool:
	return multiplayer.has_multiplayer_peer()

## Retourne le tampon du plateau (utilisé en Phase 3).
func get_plateau_tampon() -> Array:
	return _plateau_tampon

## Retourne true si le tampon du plateau est prêt.
func plateau_tampon_est_pret() -> bool:
	return _plateau_tampon_pret


# =======================================================
# RPC — Synchronisation des joueurs attendus
# =======================================================

## Envoyé par le Host à chaque nouveau Client qui se connecte.
## Informe le Client du nombre de joueurs attendus pour cette partie.
@rpc("authority", "reliable")
func rpc_definir_joueurs_attendus(nombre: int) -> void:
	joueurs_attendus = nombre
	print("NetworkManager : joueurs attendus = %d" % joueurs_attendus)

	## Recheck immédiat — _on_peer_connecte() a pu arriver avant ce RPC
	## côté Client (joueurs_attendus était 0 à ce moment → vérification ratée).
	_verifier_tous_connectes()


# =======================================================
# RPC — Synchronisation des choix (équipe + classe)
# =======================================================

## Envoyé par n'importe quel peer au Host pour soumettre son choix.
## Le Host valide (unicité de classe par équipe) et broadcast.
@rpc("any_peer", "reliable")
func rpc_soumettre_choix(equipe: int, classe: String) -> void:
	if not est_host():
		return

	var sender : int = multiplayer.get_remote_sender_id()

	## Vérifie l'unicité de la classe dans l'équipe demandée
	for id in choix_joueurs:
		if id == sender:
			continue
		var c : Dictionary = choix_joueurs[id]
		if c.get("equipe", -1) == equipe and c.get("classe", "") == classe:
			rpc_refuser_choix.rpc_id(sender, "Classe déjà prise dans cette équipe !")
			return

	## Choix valide — enregistre et broadcast
	choix_joueurs[sender] = {
		"equipe"  : equipe,
		"classe"  : classe,
		"pret"    : false,
		"est_roi" : false,
	}
	print("NetworkManager : choix validé peer %d → équipe %d classe %s"
		% [sender, equipe, classe])

	rpc_sync_choix.rpc(sender, equipe, classe)


## Envoyé par le Host à tous — met à jour le choix d'un peer.
@rpc("authority", "reliable")
func rpc_sync_choix(peer_id: int, equipe: int, classe: String) -> void:
	if not choix_joueurs.has(peer_id):
		choix_joueurs[peer_id] = _choix_vide()
	choix_joueurs[peer_id].equipe = equipe
	choix_joueurs[peer_id].classe = classe
	choix_mis_a_jour.emit(peer_id)


## Envoyé par le Host au peer dont le choix a été refusé.
@rpc("authority", "reliable")
func rpc_refuser_choix(raison: String) -> void:
	choix_refuse.emit(raison)


## Envoyé par n'importe quel peer au Host pour confirmer qu'il est prêt.
@rpc("any_peer", "reliable")
func rpc_confirmer_pret() -> void:
	if not est_host():
		return
	var sender : int = multiplayer.get_remote_sender_id()
	if choix_joueurs.has(sender):
		choix_joueurs[sender].pret = true
		print("NetworkManager : peer %d est prêt" % sender)
		_verifier_tous_prets()


## Envoyé par le Host à TOUS pour lancer la partie.
## @param configs : Array sérialisé des choix finaux
@rpc("authority", "reliable")
func rpc_lancer_partie(configs: Array) -> void:
	print("NetworkManager : lancement reçu — %d joueurs" % configs.size())
	tous_prets.emit(configs)


# =======================================================
# RPC — Synchronisation du plateau (Phase 3)
# =======================================================

## Envoyé par le Host — état complet du plateau.
## Stocké dans un tampon pour éviter les race conditions.
@rpc("authority", "reliable")
func rpc_sync_plateau(etat: Array) -> void:
	_plateau_tampon      = etat
	_plateau_tampon_pret = true
	print("NetworkManager : plateau reçu — %d cases" % etat.size())


# =======================================================
# CALLBACKS MULTIPLAYER
# =======================================================

func _on_connexion_reussie() -> void:
	print("NetworkManager : connecté ! Mon ID = %d" % get_mon_id())
	if not peers_connectes.has(get_mon_id()):
		peers_connectes.append(get_mon_id())
	connexion_reussie.emit()


func _on_connexion_echouee() -> void:
	push_warning("NetworkManager : échec de connexion.")
	connexion_echouee.emit()


func _on_peer_connecte(peer_id: int) -> void:
	print("NetworkManager : peer connecté — ID %d" % peer_id)
	if not peers_connectes.has(peer_id):
		peers_connectes.append(peer_id)

	## Host : informe le nouveau Client du nombre de joueurs attendus
	if est_host():
		rpc_definir_joueurs_attendus.rpc_id(peer_id, joueurs_attendus)
		choix_joueurs[peer_id] = _choix_vide()

	peer_connecte.emit(peer_id)

	_verifier_tous_connectes()


func _on_peer_deconnecte(peer_id: int) -> void:
	push_warning("NetworkManager : peer déconnecté — ID %d" % peer_id)
	peers_connectes.erase(peer_id)
	choix_joueurs.erase(peer_id)
	peer_deconnecte.emit(peer_id)


# =======================================================
# HELPERS PRIVÉS
# =======================================================

## Vérifie si tous les peers attendus sont connectés et émet tous_connectes.
## Appelée depuis _on_peer_connecte() ET rpc_definir_joueurs_attendus()
## pour couvrir les deux ordres d'arrivée possibles.
func _verifier_tous_connectes() -> void:
	## joueurs_attendus == 0 → Host n'a pas encore communiqué le format.
	if joueurs_attendus == 0:
		return
	if peers_connectes.size() == joueurs_attendus:
		print("NetworkManager : tous les joueurs sont connectés !")
		tous_connectes.emit()


## Retourne un Dictionary de choix vide pour un nouveau peer.
func _choix_vide() -> Dictionary:
	return { "equipe": -1, "classe": "", "pret": false, "est_roi": false }


## Vérifie si tous les peers ont confirmé leur choix.
## Appelée par le Host après chaque rpc_confirmer_pret().
func _verifier_tous_prets() -> void:
	if choix_joueurs.size() < joueurs_attendus:
		return
	for id in choix_joueurs:
		if not choix_joueurs[id].get("pret", false):
			return

	_designer_rois_si_necessaire()

	var configs : Array = []
	for id in choix_joueurs:
		var c : Dictionary = choix_joueurs[id].duplicate()
		c["peer_id"] = id
		configs.append(c)

	print("NetworkManager : tous prêts → lancement !")
	rpc_lancer_partie.rpc(configs)


## Désigne aléatoirement 1 Roi par équipe, uniquement en 3v3.
func _designer_rois_si_necessaire() -> void:
	if joueurs_attendus != FORMATS_JEU.get("3v3", 6):
		return

	var equipes : Dictionary = {}
	for id in choix_joueurs:
		var eq : int = choix_joueurs[id].get("equipe", 0)
		if not equipes.has(eq):
			equipes[eq] = []
		equipes[eq].append(id)

	for eq in equipes:
		var membres : Array = equipes[eq]
		if membres.size() > 0:
			var roi_id : int = membres[randi() % membres.size()]
			choix_joueurs[roi_id].est_roi = true
			print("NetworkManager : Roi équipe %d → peer %d" % [eq, roi_id])
