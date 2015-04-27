require! { d3, './lib/physicsjs-full.min.js': physics }

window.EB = {}

window.EB.onload = !->

  width  = 600
  height = 350

  body = d3.select \body

  game = body.append \div
    .attr  \id \game
    .style \width  "#{width}px"
    .style \height "#{height}px"
    .style \background-color \black
    .style \border-radius \30px

  game.append \img
    .attr \width  "#{width}px"
    .attr \height "#{height - 50}px"
    .attr \src 'res/table.svg'

  balls = for n til 16 then id: n, x: n * 25 + 100, y: 100

  game.select-all \.ball
    .data balls
    .enter!
    .append \img
    .attr  \class  \ball
    .attr  \width  \20px
    .attr  \height \20px
    .attr  \src  -> "res/ball-#{it.id}.svg"
    .style \top  -> it.y - 10 + \px
    .style \left -> it.x - 10 + \px

  game.append \div
    .style \top "#{height - 50}px"
    .style \width  \100%
    .style \height \50px
    .style \text-align \center
    .style \line-height \50px
    .text 'Under Construction...'

  init-physics!
  init-controls!

cue-ball = null
is-mouse-down = false
last-mouse-x = 0
last-mouse-y = 0

init-physics = !->
  ball-imgs = d3.select-all \.ball

  world <-! physics {
    timestep: 6
    maxIPF:   4
  }

  physics.renderer \custom, ->
    render: (bodies) !->
      ball-imgs
        .data (for body in bodies then x: body.state.pos.get(0), y: body.state.pos.get(1))
        .style \top  -> it.y - 10 + \px
        .style \left -> it.x - 10 + \px

  world.add physics.renderer \custom

  line = d3.select \#game
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

  physics.util.ticker.on (time) !->
    world.step time
    world.render!
    if is-mouse-down
      line
        .attr \x1 cue-ball.state.pos.get 0
        .attr \y1 cue-ball.state.pos.get 1
        .attr \x2 last-mouse-x
        .attr \y2 last-mouse-y
        .attr \visibility \visible
    else
      line.attr \visibility \hidden

  world.add physics.behavior \edge-collision-detection,
      aabb: physics.aabb 25 25 575 275
      restitution: 0.8

  world.add balls = for n til 16
    physics.body \circle,
      x: n * 25 + 100
      y: 100
      vx: (Math.random! - 0.5)
      vy: (Math.random! - 0.5)
      radius: 10
      restitution: 0.8

  cue-ball := balls[0]

  world.add balls

  world.add [
    physics.behavior \body-impulse-response
    physics.behavior \body-collision-detection
    physics.behavior \sweep-prune
  ]

  physics.util.ticker.start!


init-controls = !->
  on-down = !-> is-mouse-down := true
  on-up   = !->
    is-mouse-down := false
    force =
      x: (last-mouse-x - cue-ball.state.pos.get 0)
      y: (last-mouse-y - cue-ball.state.pos.get 1)
    mag = 10 * Math.sqrt (force.x * force.x + force.y * force.y)
    force.x /= mag
    force.y /= mag
    cue-ball.apply-force force
  on-move = !->
    last-mouse-x := it.client-x
    last-mouse-y := it.client-y

  document.body.add-event-listener
    .. \mousedown  on-down
    .. \touchstart on-down
    .. \mouseup    on-up
    .. \touchend   on-up
    .. \mousemove  on-move
    .. \touchmove  on-move
