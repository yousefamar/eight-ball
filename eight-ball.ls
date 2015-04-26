require! { d3, \matter-js : { Engine, World, Bodies, Composite, Body }:matter }

window.EB = {}

window.EB.onload = !->

  width  = 800
  height = 450

  body = d3.select \body

  game = body.append \div
    .attr  \id \game
    .style \width  "#{width}px"
    .style \height "#{height}px"
    .style \background-color \black
    .style \border-radius \30px

  game.append \img
    .attr \src 'res/table.svg'

  balls = for n til 16 then id: n, cx: n * 25 + 100, cy: 100

  game.append \svg
    .attr  \width  \100%
    .attr  \height \100%
    .style \left \0
    .select-all \circle
    .data balls
    .enter!
    .append \circle
      .attr \cx -> it.cx
      .attr \cy -> it.cy
      .attr \r  \10
      .style \fill \#DDDDDD

  game.append \div
    .style \top \400px
    .style \width  \100%
    .style \height \50px
    .style \text-align \center
    .style \line-height \50px
    .text 'Under Construction...'

  init-physics!

init-physics = !->
  circles = d3.select-all \circle

  renderer =
    create: -> controller: renderer
    clear: ->
    world: (engine) !->
      balls = Composite.all-bodies engine.world .slice 4
      circles
        .data (for ball in balls then cx: ball.position.x, cy: ball.position.y)
        .attr \cx -> it.cx
        .attr \cy -> it.cy

  engine = Engine.create { render: controller: renderer }, position-iterations: 1, velocity-iterations: 1
    ..world.gravity.y = 0

  walls = []
    ..push Bodies.rectangle 400, 15,  800, 30,  { +is-static, restitution: 1 }
    ..push Bodies.rectangle 400, 385, 800, 30,  { +is-static, restitution: 1 }
    ..push Bodies.rectangle 15,  200, 30,  320, { +is-static, restitution: 1 }
    ..push Bodies.rectangle 785, 200, 30,  320, { +is-static, restitution: 1 }

  balls = for n til 16 then Bodies.circle n * 25 + 100, 100, 10, restitution: 1

  for ball in balls then Body.apply-force ball, ball.position, { x: (Math.random! - 0.5) / 50, y: (Math.random! - 0.5) / 50 }

  World.add engine.world, walls

  World.add engine.world, balls

  Engine.run engine
