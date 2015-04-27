require! { d3, \matter-js : { Engine, World, Bodies, Composite, Body }:matter }

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
  console.log balls

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

engine = null
is-mouse-down = false
last-mouse-x = 0
last-mouse-y = 0

init-physics = !->
  ball-imgs = d3.select-all \.ball

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

  renderer =
    create: -> controller: renderer
    clear: ->
    world: (engine) !->
      balls = Composite.all-bodies engine.world .slice 4
      if is-mouse-down
        white-ball = balls[0]
        line
          .attr \x1 white-ball.position.x
          .attr \y1 white-ball.position.y
          .attr \x2 last-mouse-x
          .attr \y2 last-mouse-y
          .attr \visibility \visible
      else
        line.attr \visibility \hidden
      ball-imgs
        .data (for ball in balls then x: ball.position.x, y: ball.position.y)
        .style \top  -> it.y - 10 + \px
        .style \left -> it.x - 10 + \px

  engine := Engine.create { render: controller: renderer }, position-iterations: 1, velocity-iterations: 1
    ..world.gravity.y = 0

  walls = []
    ..push Bodies.rectangle 300,   12.5,  600, 25,  { +is-static, restitution: 1 }
    ..push Bodies.rectangle 300,   287.5, 600, 25,  { +is-static, restitution: 1 }
    ..push Bodies.rectangle 12.5,  150,   25,  250, { +is-static, restitution: 1 }
    ..push Bodies.rectangle 587.5, 150,   25,  250, { +is-static, restitution: 1 }

  balls = for n til 16 then Bodies.circle n * 25 + 100, 100, 10, restitution: 1

  for ball in balls then Body.apply-force ball, ball.position, { x: (Math.random! - 0.5) / 50, y: (Math.random! - 0.5) / 50 }

  World.add engine.world, walls

  World.add engine.world, balls

  Engine.run engine

init-controls = !->
  document.body.add-event-listener \mousedown !-> is-mouse-down := true

  document.body.add-event-listener \mouseup   !->
    is-mouse-down := false
    white-ball = Composite.all-bodies engine.world .[4]
    force =
      x: (last-mouse-x - white-ball.position.x)
      y: (last-mouse-y - white-ball.position.y)
    mag = 100 * Math.sqrt (force.x * force.x + force.y * force.y)
    force.x /= mag
    force.y /= mag
    Body.apply-force white-ball, white-ball.position, force

  document.body.add-event-listener \mousemove !->
    last-mouse-x := it.client-x
    last-mouse-y := it.client-y
