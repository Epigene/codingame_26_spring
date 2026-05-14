debug "Game starts!"

# game loop
@turn = 0
loop do
  @turn += 1

  lines = [
    gets.chomp,
    gets.chomp,
    gets.chomp
  ]

  lines.last.to_i.times do
    lines << gets.chomp
    # type, x, y, size, health, fruits, cooldown = gets.split
    # x = x.to_i
    # y = y.to_i
    # size = size.to_i
    # health = health.to_i
    # fruits = fruits.to_i
    # cooldown = cooldown.to_i
    # trees << Tree.new(type, x, y, size, health, fruits, cooldown)
  end

  # workers = []
  # worker_count = gets.to_i
  lines << gets.chomp
  lines.last.to_i.times do
    lines << gets.chomp
    # id, player, x, y, movement_speed, carry_capacity, harvest_power, chop_power, carry_plum, carry_lemon, carry_apple, carry_banana, carry_iron, carry_wood = gets.split.map { |x| x.to_i }

    # workers << Worker.new(
    #   id, player, x, y,
    #   movement_speed, carry_capacity, harvest_power, chop_power,
    #   carry_plum, carry_lemon, carry_apple, carry_banana, carry_iron, carry_wood
    # )
  end

  puts @controller.call(turn: @turn, input: lines.join("\n"))
end
