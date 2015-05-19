#!/usr/bin/env lsc

require! { http, ecstatic, websocket: { server: WebSocketServer }:ws, './room.ls': { Room } }

# Log with timestamp
log = (...args) !-> console.log.call console, ([new Date!] ++ args).join " "

server = http.create-server ecstatic { root : "#__dirname/..", default-ext : \html }

server.listen 9982 !-> log 'Server started'

ws-server = new WebSocketServer do
  http-server: server
  auto-accept-connections: false

# TODO: Check origin
origin-allowed = (origin) -> true

rooms = {}

handlers =

  join: (data, connection) !->
    return unless data.roomid
    if data.roomid not of rooms then rooms[data.roomid] = new Room data.roomid
    room = rooms[data.roomid]

    if data.name? then connection.name = data.name
    connection.room = room
    room.join connection

    log (if data.name? then "Player #{data.name}" else 'Spectator') + " joined #{data.roomid} (P: #{room.players.length}, S: #{room.spectators.length}, T: #{room.connections.length})."

  aim: (data, connection) !->
    return unless connection.room?
    connection.room.aim? data, connection

  shoot: (data, connection) !->
    return unless connection.room? and connection.name?
    connection.room.shoot? data, connection

  place: (data, connection) !->
    return unless connection.room? and connection.name?
    connection.room.place? data, connection

  broadcast: (data, connection) !->
    return unless connection.room?
    connection.room.broadcast-as connection, \broadcast, data

ws-server.on \request (request) !->
  unless origin-allowed request.origin
    request.reject!
    log "Connection from origin #{request.origin} rejected"

  connection = request.accept \eight-ball request.origin

  log 'Connection accepted'

  connection.send = (type, data) !-> { type, data } |> JSON.stringify |> connection.send-UTF

  connection.on \message (message) !->
    if message.type is \utf8
      try message = JSON.parse message.utf8-data catch then return
      if message.type? then handlers[message.type]? message.data, connection
    #else if message.type is 'binary'
    #  log 'Received Binary Message of ' + message.binary-data.length + ' bytes'

  connection.on \close (reason-code, description) !->
    if connection.room?
      connection.room.part connection
      if connection.room.connections.length is 0 then delete rooms[connection.room.id]
    log "Client #{connection.remote-address} disconnected"

tick = !->
  set-timeout tick, 1000.0/60.0
  for i, room of rooms then room.tick!

set-timeout tick, 1000.0/60.0
