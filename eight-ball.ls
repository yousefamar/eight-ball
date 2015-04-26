require! { d3, \matter-js }

window.EB = {}

window.EB.onload = !->

  width  = 800
  height = 450

  body = d3.select \body

  game = body.append \div
    .style \width  "#{width}px"
    .style \height "#{height}px"
    .style \background-color \black
    .style \border-radius \30px

  game.append \object
    .attr \data 'res/table.svg'

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
