require! { url, d3, websocket: { w3cwebsocket: W3CWebSocket }:ws }

window.EB = {}

get-vars = window.location.href |> url.parse _, true |> (.query)

build-audio-player = (url, clone-count) ->
  audio = new Audio url
  clones = for til clone-count then audio.clone-node!
  id = 0
  (volume) !->
    clones[id]
      ..volume = volume
      ..play!
    id := (id + 1) % clone-count

sounds =
  ball-collision:
    play: build-audio-player 'res/ball-collision.ogg' 10
  pocket:
    play: build-audio-player 'res/pocket.ogg' 6
  cue-shot:
    play: build-audio-player 'res/cue-shot.ogg' 1

sock-send = !-> console.error 'Cannot send to server'

is-own-turn = false
is-stick-visible = false
is-own-stick = false
aim-x = 0
aim-y = 0
aim-angle = 0

player-names = []
spectator-count = 0

handlers =

  'game-state': (data) !->
    if data.players[0]? then d3.select \#player1-name .text player-names[0] = data.players[0]
    if data.players[1]? then d3.select \#player2-name .text player-names[1] = data.players[1]
    d3.select \#spectator-panel .text "Spectators: #{spectator-count := data.spectator-count}"

    for ball-state in data.ball-states
      ball = d3.select \# + ball-state.id
      if ball-state.sunk
        ball.remove!
        continue
      ball
        .attr \data-x ball-state.x
        .attr \data-y ball-state.y
        .style \top  ball-state.y - 10 + \px
        .style \left ball-state.x - 10 + \px

  'join': (name) !->
    if name?
      unless player-names[0]?
        d3.select \#player1-name .text player-names[0] = name
      else
        d3.select \#player2-name .text player-names[1] = name
    else
      d3.select \#spectator-panel .text "Spectators: #{++spectator-count}"

  'part': (name) !->
    if name?
      is-own-turn := false
      player-names.index-of name |> player-names.splice _, 1
      d3.select \#player1-name
        .style \color \#EEEEEE
        .text if player-names[0]? then player-names[0] else 'Waiting for player 1...'
      d3.select \#player2-name
        .style \color \#EEEEEE
        .text if player-names[1]? then player-names[1] else 'Waiting for player 2...'
    else
      d3.select \#spectator-panel .text "Spectators: #{--spectator-count}"

  'ball-pos': (poss) !->
    for pos in poss
      d3.select \# + pos.id
        .attr \data-x pos.x
        .attr \data-y pos.y
        .style \top  pos.y - 10 + \px
        .style \left pos.x - 10 + \px

  'ball-sink': (id) !->
    d3.select \# + id .remove!
    sounds.pocket.play 1

  'ball-collision': (overlap) !->
    sounds.ball-collision.play overlap

  'turn': (player-id) !->
    is-own-turn := player-names[player-id] is get-vars.player
    d3.select \#player1-name .style \color \#555555
    d3.select \#player2-name .style \color \#555555
    d3.select "\#player#{player-id + 1}-name" .style \color \#EEEEEE

  'aim': (coords) !->
    is-stick-visible := true
    is-own-stick     := false
    aim-x := coords.x
    aim-y := coords.y
    update-aim-angle!

  'shoot': !->
    is-stick-visible := false
    sounds.cue-shot.play 1


connect = (callback) !->
  uid = null

  sock = new W3CWebSocket 'ws://amar.io:9982/' \eight-ball

    ..onerror = !->
      console.error 'Could not connect to server'

    ..onopen = !->
      console.log 'Connected to server'
      callback!

    ..onclose = !->
      console.log 'Connection to server closed'

    ..onmessage = (event) !->
      try message = JSON.parse event.data catch then return
      if message.type? then handlers[message.type]? message.data

  window.onbeforeunload = !-> sock.close!

  sock-send := (type, data) !-> { type, data } |> JSON.stringify |> sock.send

window.EB.onload = !->
  width  = 600
  height = 340

  body = d3.select \body

  game = body.append \div
    .attr  \id \game
    .style \width  "#{width}px"
    .style \height "#{height}px"
    .style \background-color \black
    .style \border-radius \30px
    .style \overflow \hidden

  game.append \img
    .attr \width  "#{width}px"
    .attr \height "#{height - 40}px"
    .attr \src 'res/table.svg'

  radius = 10
  diameter = 2 * radius
  offset = Math.sqrt (diameter * diameter) - (radius * radius)

  width-edge = width / 24
  width-felt = width - 2 * width-edge
  line-x = width-edge + width-felt / 5
  balls-x = width - width-edge - width-felt / 4

  init-ball-poss =
    { x: line-x, y: 150 }
    { x: balls-x, y: 150 }
    { x: balls-x + 3 * offset, y: 150 - 1 * radius }
    { x: balls-x + 2 * offset, y: 150 + 2 * radius }
    { x: balls-x + 4 * offset, y: 150 + 4 * radius }
    { x: balls-x + 1 * offset, y: 150 - 1 * radius }
    { x: balls-x + 4 * offset, y: 150 }
    { x: balls-x + 4 * offset, y: 150 - 2 * radius }
    { x: balls-x + 2 * offset, y: 150 }
    { x: balls-x + 3 * offset, y: 150 + 3 * radius }
    { x: balls-x + 1 * offset, y: 150 + 1 * radius }
    { x: balls-x + 4 * offset, y: 150 - 4 * radius }
    { x: balls-x + 2 * offset, y: 150 - 2 * radius }
    { x: balls-x + 3 * offset, y: 150 + 1 * radius }
    { x: balls-x + 3 * offset, y: 150 - 3 * radius }
    { x: balls-x + 4 * offset, y: 150 + 2 * radius }

  balls = for n til 16 then id: n, x: init-ball-poss[n].x, y: init-ball-poss[n].y

  game.select-all \.ball
    .data balls
    .enter!
    .append \img
    .attr  \id -> "ball-#{it.id}"
    .attr  \class  \ball
    .attr  \width  \20px
    .attr  \height \20px
    .attr  \src  -> "res/ball-#{it.id}.svg"
    .style \top  -> it.y - 10 + \px
    .style \left -> it.x - 10 + \px

  info-bar = game.append \div
    .attr  \id \info-bar
    .style \top "#{height - 40}px"
    .style \width  \100%
    .style \height \40px
    #.style \text-align \center
    #.style \line-height \40px

  player-panel = info-bar.append \div
    .style \position \relative
    .style \float \left
    .style \font-size \50%

  player-panel.append \div
    .attr \id \player1-name
    .style \position \relative
    .style \margin '10px 30px'
    .text 'Waiting for player 1...'

  player-panel.append \div
    .attr \id \player2-name
    .style \position \relative
    .style \margin '10px 30px'
    .text 'Waiting for player 2...'

  info-bar.append \div
    .attr \id \spectator-panel
    .style \position \relative
    .style \float \right
    .style \margin '10px 30px'
    .style \font-size \50%
    .text 'Spectators: 0'

  <-! connect

  sock-send \join { get-vars.roomid, name: get-vars.player }
  init-controls!

update-aim-angle = !->
  cue-ball = d3.select \#ball-0
  x = aim-x - parse-float cue-ball.attr \data-x
  y = aim-y - parse-float cue-ball.attr \data-y
  aim-angle := 1.57079632679 + Math.atan2 y, x

init-controls = !->
  game = d3.select \#game
  is-mouse-down = false

  stick = game.append \img
    .attr \width  "20px"
    .attr \height "500px"
    .attr \src 'res/stick.svg'
    .style \transform-origin 'center top'
    .style \visibility \hidden

  line = game
    .append \svg
    .attr  \width  \100%
    .attr  \height \100%
    .style \left \0
    .append \line
      .attr \x1 \0
      .attr \y1 \0
      .attr \x2 \0
      .attr \y2 \0
      .style \stroke \#771F1F
      .style \stroke-width \2

  cue-ball = d3.select \#ball-0

  render = !->
    request-animation-frame render

    if is-stick-visible
      cue-x = parse-float cue-ball.attr \data-x
      cue-y = parse-float cue-ball.attr \data-y
      stick
        .style \top  cue-y + \px
        .style \left cue-x - 10 + \px
        .style \transform "rotate(#{aim-angle}rad) translate(0px, 20px)"
        .style \opacity if is-own-stick then 1 else 0.5
        .style \visibility \visible
      line
        .attr \x1 cue-x
        .attr \y1 cue-y
        .attr \x2 aim-x
        .attr \y2 aim-y
        .style \opacity if is-own-stick then 1 else 0.5
        .attr \visibility \visible
    else
      line.attr   \visibility \hidden
      stick.style \visibility \hidden

  request-animation-frame render

  unless \player of get-vars then return

  on-down = !->
    unless is-own-turn then return
    is-mouse-down    := true
    is-stick-visible := true
    is-own-stick     := true
    update-aim-angle!
  on-up   = !->
    unless is-own-turn then return
    is-own-turn := false
    is-mouse-down    := false
    is-stick-visible := false
    force =
      x: aim-x - parse-float cue-ball.attr \data-x
      y: aim-y - parse-float cue-ball.attr \data-y
    mag = 10 * Math.sqrt (force.x * force.x + force.y * force.y)
    force.x /= mag
    force.y /= mag
    sock-send \shoot force
    sounds.cue-shot.play 1
  on-move = !->
    unless is-own-turn then return
    aim-x := it.client-x
    aim-y := it.client-y
    if is-mouse-down
      update-aim-angle!
      sock-send \aim { x: aim-x, y: aim-y }

  document.body.add-event-listener
    .. \mousedown  on-down
    .. \touchstart on-down
    .. \mouseup    on-up
    .. \touchend   on-up
    .. \mousemove  on-move
    .. \touchmove  on-move
