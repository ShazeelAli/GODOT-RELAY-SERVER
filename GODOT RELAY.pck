GDPC                                                                                       	   P   res://.godot/exported/206107301/export-218a8f2b3041327d8a5756f3a245f83b-icon.res�       '      Q$[>���5R�	.    T   res://.godot/exported/206107301/export-a2ff065442e2d235f6bedbb6028aca18-relay.scn   �      $      ���������B5�ؓF    ,   res://.godot/global_script_class_cache.cfg  `             ��Р�8���8~$}P�       res://.godot/uid_cache.bin  @      :       ���^��m)���Ʊ%       res://RELAY.gd         �      �$m���كu�5W       res://icon.svg  �      �      C��=U���^Qu��U3       res://icon.svg.import           �       ��y�����q�I5Afb�       res://project.binary�      �      -�,���$�78 ��       res://relay.tscn.remap  �      b       �/�e��?�?42�ܦ        [remap]

importer="texture"
type="PlaceholderTexture2D"
uid="uid://bkwiamwpsd4xu"
metadata={
"vram_texture": false
}
path="res://.godot/exported/206107301/export-218a8f2b3041327d8a5756f3a245f83b-icon.res"
   RSRC                    PlaceholderTexture2D            ��������                                                  resource_local_to_scene    resource_name    size    script        #   local://PlaceholderTexture2D_hfay7 �          PlaceholderTexture2D       
      C   C      RSRC         extends Node2D


@export var PLAYER_DICT = {}
@export var ROOMS = {}
var CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";

## Supplementary functions
func create_room_code():
	var id = ""
	for n in 5:
		var random_number =  randi_range(0,CHARS.length() -1)
		var random_char = CHARS[random_number]
		id+=random_char
	if ROOMS.has(id):
		return create_room_code()
	
	return id
	
### ALL CODE PERTAINING TO RELAY CONNECTION
# Called when the node enters the scene tree for the first time
# Sets Up Server Socket
func _ready():
	var relay_peer = ENetMultiplayerPeer.new()
	var error = relay_peer.create_server(25566)
	if error:
		return(error)
	multiplayer.multiplayer_peer = relay_peer
	
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
## CREATES PLAYER ON JOIN
@rpc("any_peer","call_remote","reliable")
func _resgister_player():
	var new_player_id = multiplayer.get_remote_sender_id()
	PLAYER_DICT[new_player_id] = {
		"player_name":"EMPTY",
		"room_code":"EMPTY",
		"is_host":false,
		"multiplayer_id":0
	}

func _on_player_disconnected(id):
	
	if !PLAYER_DICT.has(id):
		return

	var player_data = PLAYER_DICT[id]
	var room_code = player_data.room_code
	PLAYER_DICT.erase(id)
	if player_data.is_host == true:
		ROOMS[room_code].players.erase(id)
		close_room(room_code)
	elif ROOMS.has(room_code):
		ROOMS[room_code].players.erase(id)
		remove_player(room_code,id)

@rpc("any_peer","call_remote","reliable")
func leave_command():
	var sender_id = multiplayer.get_remote_sender_id()
	var player_room_id = PLAYER_DICT[sender_id].room_code
	if ROOMS.has(player_room_id):
		if ROOMS[player_room_id].host_id == sender_id:
			close_room(player_room_id)
		else:
			remove_player(player_room_id,sender_id)

func close_room(room_code):
	for player_id in ROOMS[room_code].players:
		room_closed.rpc_id(player_id)
	ROOMS.erase(room_code)
	
@rpc("any_peer","call_remote","reliable")
func remove_player_command(player_to_remove):
	var sender_id = multiplayer.get_remote_sender_id()
	var player_room_id = PLAYER_DICT[sender_id].room_code
	if ROOMS.has(player_room_id):
		if ROOMS[player_room_id].host_id == sender_id:
			remove_player(player_room_id,player_to_remove)

func remove_player(room_code,player_id_to_remove):
	for player_id in ROOMS[room_code].players:
		player_disconnect_room.rpc_id(player_id,player_id_to_remove)
	if(PLAYER_DICT.has(player_id_to_remove)):
		PLAYER_DICT[player_id_to_remove].room_code = "EMPTY"
		PLAYER_DICT[player_id_to_remove].is_host = false
	
	ROOMS[room_code].players.erase(player_id_to_remove)
	sync_room_data_all(room_code)

## HOSTING ROOM CODE
@rpc("any_peer","call_remote","reliable")
func host_rpc():
	var room_code = create_room_code()
	var sender_id = multiplayer.get_remote_sender_id()
	PLAYER_DICT[sender_id].room_code = room_code
	PLAYER_DICT[sender_id].is_host = true;
	ROOMS[room_code] = {
		"room_code":room_code,
		"host_id":0,
		"players":{},
		"max_players":3,
		"game_started":false,
		"is_public":false
	}
	
	ROOMS[room_code].host_id = sender_id
	ROOMS[room_code].players[sender_id] = PLAYER_DICT[sender_id]
	host_success_rpc.rpc_id(sender_id,room_code,ROOMS[room_code])
	sync_room_data_all(room_code)
	
@rpc("authority","call_remote","reliable")
func host_success_rpc(room_code : String,room_info : Dictionary):
	pass

@rpc("authority","call_remote","reliable")
func host_fail_rpc(room_code : String, error_message : String):
	pass	


## JOINING ROOM CODE
@rpc("any_peer","call_remote","reliable")
func join_rpc(room_code : String):
	var sender_id = multiplayer.get_remote_sender_id()
	if !ROOMS.has(room_code):
		join_fail_rpc.rpc_id(sender_id,room_code,"NO ROOM FOUND")
		return
	
	if ROOMS[room_code].max_players <= ROOMS[room_code].players.size():
		join_fail_rpc.rpc_id(sender_id,room_code,"ROOM IS FULL")
		return
	
	if ROOMS[room_code].game_started:
		join_fail_rpc.rpc_id(sender_id,room_code,"GAME HAS STARTED")
		return
	
	PLAYER_DICT[sender_id].room_code = room_code
	ROOMS[room_code].players[sender_id] = PLAYER_DICT[sender_id]
	for player_id in ROOMS[room_code].players:
		join_success_rpc.rpc_id(player_id,ROOMS[room_code],sender_id)
	sync_room_data_all(room_code)
	

@rpc("authority","call_remote","reliable")
func join_success_rpc(room_info : Dictionary, player_id_joined : int):
	pass

@rpc("authority","call_remote","reliable")
func join_fail_rpc(room_code : String, error_message : String):
	pass

@rpc("authority","call_remote","reliable")
func player_disconnect_room(player_disconnecting_id):
	pass

@rpc("authority","call_remote","reliable")
func room_closed():
	pass
## Sync room info
func sync_room_data_all(room_code : String):
	for player_id in ROOMS[room_code].players:
		sync_room_data_rpc.rpc_id(player_id,ROOMS[room_code])
		
@rpc("authority","reliable")
func sync_room_data_rpc(room_data : Dictionary):
	pass
	
@rpc("any_peer","reliable")
func game_started_rpc(started : bool):
	var sender_id = multiplayer.get_remote_sender_id()
	var room_id  = PLAYER_DICT[sender_id].room_code
	ROOMS[room_id].game_started = started
	
### END OF RELAY SERVER CONNECTION 


        RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script           local://PackedScene_p7uwx �          PackedScene          	         names "         RELAY    Node2D    	   variants              node_count             nodes        ��������       ����              conn_count              conns               node_paths              editable_instances              version             RSRC            [remap]

path="res://.godot/exported/206107301/export-a2ff065442e2d235f6bedbb6028aca18-relay.scn"
              list=Array[Dictionary]([])
     <svg height="128" width="128" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="124" height="124" rx="14" fill="#363d52" stroke="#212532" stroke-width="4"/><g transform="scale(.101) translate(122 122)"><g fill="#fff"><path d="M105 673v33q407 354 814 0v-33z"/><path fill="#478cbf" d="m105 673 152 14q12 1 15 14l4 67 132 10 8-61q2-11 15-15h162q13 4 15 15l8 61 132-10 4-67q3-13 15-14l152-14V427q30-39 56-81-35-59-83-108-43 20-82 47-40-37-88-64 7-51 8-102-59-28-123-42-26 43-46 89-49-7-98 0-20-46-46-89-64 14-123 42 1 51 8 102-48 27-88 64-39-27-82-47-48 49-83 108 26 42 56 81zm0 33v39c0 276 813 276 813 0v-39l-134 12-5 69q-2 10-14 13l-162 11q-12 0-16-11l-10-65H447l-10 65q-4 11-16 11l-162-11q-12-3-14-13l-5-69z"/><path d="M483 600c3 34 55 34 58 0v-86c-3-34-55-34-58 0z"/><circle cx="725" cy="526" r="90"/><circle cx="299" cy="526" r="90"/></g><g fill="#414042"><circle cx="307" cy="532" r="60"/><circle cx="717" cy="532" r="60"/></g></g></svg>
             .���~+   res://icon.svg	�2���e   res://relay.tscn      ECFG      _custom_features         dedicated_server   application/config/name         GODOT RELAY    application/run/main_scene         res://relay.tscn   application/config/features$   "         4.2    Forward Plus       application/config/icon         res://icon.svg     autoload/Relayconnect         *res://RELAY.gd    dotnet/project/assembly_name         GODOT RELAY 