#!/usr/bin/env lsc

require! { http, ecstatic, websocket: { server: WebSocketServer }:ws, './room.ls': { Room } }

server = http.create-server ecstatic { root : "#__dirname/..", default-ext : \html }

server.listen 9982 !->
  console.log new Date! + ' Server started'

ws-server = new WebSocketServer {
  http-server: server
  auto-accept-connections: false
}

# TODO: Check origin
origin-allowed = (origin) -> true

rooms = {}

handlers =

  join: (data, connection) !->
    unless data.roomid then return
    if data.roomid not of rooms then rooms[data.roomid] = new Room data.roomid
    room = rooms[data.roomid]

    if data.name? then connection.name = data.name
    connection.room = room
    room.join connection

    console.log new Date! + (if data.name? then " Player #{data.name}" else ' Spectator') + " joined #{data.roomid} (P: #{room.players.length}, S: #{room.spectators.length}, T: #{room.connections.length})."

  aim: (data, connection) !->
    unless connection.room? then return
    connection.room.aim? data, connection

  shoot: (data, connection) !->
    unless connection.room? and connection.name? then return
    connection.room.shoot? data, connection

  place: (data, connection) !->
    unless connection.room? and connection.name? then return
    connection.room.place? data, connection

  broadcast: (data, connection) !->
    unless connection.room? then return
    connection.room.broadcast-as connection, \broadcast, data

ws-server.on \request (request) !->
  unless origin-allowed request.origin
    request.reject!
    console.log new Date! + ' Connection from origin ' + request.origin + ' rejected'
    return

  connection = request.accept \eight-ball request.origin

  console.log new Date! + ' Connection accepted'

  connection.send = (type, data) !-> { type, data } |> JSON.stringify |> connection.send-UTF

  connection.on \message (message) !->
    if message.type is \utf8
      try message = JSON.parse message.utf8-data catch then return
      if message.type? then handlers[message.type]? message.data, connection
    #else if message.type is 'binary'
    #  console.log new Date! + ' Received Binary Message of ' + message.binary-data.length + ' bytes'

  connection.on \close (reason-code, description) !->
    if connection.room?
      connection.room.part connection
      if connection.room.connections.length is 0 then delete rooms[connection.room.id]
    console.log new Date! + " Client #{connection.remote-address} disconnected"

tick = !->
  set-timeout tick, 1000.0/60.0
  for i, room of rooms then room.tick!

set-timeout tick, 1000.0/60.0
