require! { './lib/physicsjs-full.min.js': physics }

export class Room
  (@id) ->
    # States: waiting, simulating, playing
    @state = \waiting
    @turn = 0
    @connections = []
    @players     = []
    @spectators  = []
    @balls = []

  join: (connection) !->
    if connection.name? and @players.length >= 2 then delete connection.name
    @connections.push connection
    if connection.name? then @players.push connection else @spectators.push connection
    @broadcast-as connection, \join, connection.name

    connection.send \game-state, {
      players: for player in @players then player.name
      spectator-count: @spectators.length
      ball-states: for ball in @balls then { ball.id, x: ball.state.pos.x, y: ball.state.pos.y, ball.sunk }
    }

    if @state is \waiting and @players.length >= 2
      @init-physics!
      @state = \simulating

  part: (connection) !->
    if @connections.index-of(connection) < 0 then return
    @connections.index-of connection |> @connections.splice _, 1
    unless @players.index-of(connection) < 0
      @players.index-of connection |> @players.splice _, 1
    unless @spectators.index-of(connection) < 0
      @spectators.index-of connection |> @spectators.splice _, 1
    @broadcast \part, connection.name

  broadcast: (type, data) !-> for conn in @connections then conn.send type, data

  broadcast-as: (connection, type, data) !->
    for conn in @connections
      unless conn is connection
        conn.send type, data

  init-physics: !->
    console.log 'Initialising physics'

    self = @

    world <-! physics {
      timestep: 6
      max-IPF:  4
    }

    all-balls-sleeping = ->
      for ball in balls then unless ball.sleep! then return false
      return true

    tick = !->
      set-timeout tick, 1000.0/60.0

      world.step new Date!.get-time!

      unless self.state is \simulating then return

      ball-poss = []

      for ball in balls
        unless ball.state.pos.x is ball.last-pos.x
           and ball.state.pos.y is ball.last-pos.y
             ball-poss.push { ball.id, x: ball.state.pos.x, y: ball.state.pos.y }
        ball.last-pos.x = ball.state.pos.x
        ball.last-pos.y = ball.state.pos.y

      if ball-poss.length then self.broadcast \ball-pos ball-poss

      if all-balls-sleeping!
        self.state = \playing
        self.broadcast \turn self.turn

    world.add physics.behavior \edge-collision-detection,
      aabb: physics.aabb 25 25 575 275
      restitution: 0.8
      cof: 0

    world.add balls = self.balls = for n til 16
      physics.body \circle,
        id: "ball-#n"
        class: \ball
        x: n * 25 + 100
        y: 100
        vx: (Math.random! - 0.5)
        vy: (Math.random! - 0.5)
        radius: 10
        restitution: 1
        cof: 0

    for ball in balls then ball.last-pos = { x: 0, y: 0}

    cue-ball = balls[0]

    self.aim = (coords, connection) !->
      unless self.state is \playing and connection is @players[@turn] then return
      connection.room.broadcast-as connection, \aim, coords

    self.shoot = (force, connection) !->
      unless self.state is \playing and connection is @players[@turn] then return
      self.state = \simulating
      cue-ball.sleep false
      cue-ball.apply-force force
      @turn = (@turn + 1) % 2
      self.broadcast-as connection, \shoot

    world.add holes = for n til 6
      physics.body \circle,
        class: \hole
        treatment: \static
        x: 30 + (n % 3) * 270
        y: 30 + (Math.floor(n / 3)) * 240
        radius: 8

    holes[1].state.pos.y -= 8
    holes[4].state.pos.y += 8

    world.add [
      physics.behavior \body-impulse-response
      physics.behavior \body-collision-detection
      physics.behavior \sweep-prune
      physics.integrator \velocity-verlet drag: 0.004
    ]

    world.on \collisions:detected (data) !-> for c in data.collisions then world.emit \collision-pair { c.body-a, c.body-b, c.overlap }

    world.on \collision-pair !->
      it.overlap = Math.max 0 Math.min 1 it.overlap
      if it.body-a.class is \ball and it.body-b.class is \ball then self.broadcast \ball-collision it.overlap
      sinkee = null
      if      it.body-a.class is \ball and it.body-b.class is \hole then sinkee = it.body-a
      else if it.body-b.class is \ball and it.body-a.class is \hole then sinkee = it.body-b
      if sinkee?
        sinkee.sunk = true
        sinkee.sleep true
        world.remove-body sinkee
        self.broadcast \ball-sink sinkee.id

    set-timeout tick, 1000.0/60.0
