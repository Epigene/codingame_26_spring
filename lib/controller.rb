Camp = Struct.new(:my, :x, :y) do
  def node
    @node ||= "#{x} #{y}"
  end
end
Inventory = Struct.new(:plum, :lemon, :apple, :banana, :iron, :wood)
Tree = Struct.new(:type, :x, :y, :size, :health, :fruits, :cooldown) do
  def node
    @node ||= "#{x} #{y}"
  end

  def fruit?
    fruits >= 1
  end
end
Worker = Struct.new(:id, :player, :x, :y,
  :movement_speed, :carry_capacity, :harvest_power, :chop_power,
  :carry_plum, :carry_lemon, :carry_apple, :carry_banana, :carry_iron, :carry_wood
) do
  def node
    @node ||= "#{x} #{y}"
  end

  def my?
    player.zero?
  end

  def full?
    [carry_plum, carry_lemon, carry_apple, carry_banana, carry_iron, carry_wood].sum >= carry_capacity
  end
end

class Controller
  attr_reader :field, :turn, :input, :grid,
    :my_camp, :opp_camp, :my_inventory, :opp_inventory,
    :trees, :workers

  # @param field String # multiline heredoc style
  def initialize(field:)
    @field = field
    init_grid
  end

  # @param turn Integer
  # @param input String # the raw as-is multiline input provided by game
  # @return String
  def call(turn:, input:)
    @turn = turn
    debug(@input = input)
    init_turn_variables!

    @commands = []
    workers.select { _1.my? }.each do |worker|
      if worker.full?
        home_paths = grid.n4(my_camp.node).map { [_1, grid.shortest_path(worker.node, _1)]}
        next_to_home_node, path = home_paths.sort_by { |node, path| grid.path_length(path) }.first

        if next_to_home_node && path.size == 1 # let's deposit!
           @commands << "DROP #{worker.id}"
        elsif
          @commands << "MOVE #{worker.id} #{next_to_home_node}"
        end
      else
        fruit_paths = trees.select { _1.fruit? }.map { [_1, grid.shortest_path(worker.node, _1.node)] }
        closest_fruit_tree, path = fruit_paths.sort_by { |tree, path| grid.path_length(path) }.first

        if closest_fruit_tree && path.size == 1 # let's harvest!
          @commands << "HARVEST #{worker.id}"
        elsif closest_fruit_tree
          @commands << "MOVE #{worker.id} #{closest_fruit_tree.node}"
        end
      end
    end

    (result = @commands.join("; ")) == "" ? "WAIT" : result
  end

  private

  def init_turn_variables!
    lines = input.split("\n")

    @my_inventory = Inventory.new(*lines.shift.split.map(&:to_i))
    @opp_inventory = Inventory.new(*lines.shift.split.map(&:to_i))

    @trees = []
    lines.shift.to_i.times do
      type, x, y, size, health, fruits, cooldown = lines.shift.split.map { _1[0].match?(%r'\d') ? _1.to_i : _1 }
      @trees << Tree.new(type, x, y, size, health, fruits, cooldown)
    end

    @workers = []
    lines.shift.to_i.times do
      id, player, x, y, movement_speed, carry_capacity, harvest_power, chop_power, carry_plum, carry_lemon, carry_apple, carry_banana, carry_iron, carry_wood = lines.shift.split.map(&:to_i)

      @workers << Worker.new(
        id, player, x, y,
        movement_speed, carry_capacity, harvest_power, chop_power,
        carry_plum, carry_lemon, carry_apple, carry_banana, carry_iron, carry_wood
      )
    end
  end

  # Grid init is a simple fill, bet we make caps leave-only (and maybe rocks in future leagues)
  def init_grid
    lines = field.split("\n")
    @grid = Grid.new(lines.first.size, lines.size, fill: true)

    lines.each_with_index do |line, y|
      line.split("").each_with_index do |cell, x|
        next unless cell == "0" || cell == "1"

        @my_camp = Camp.new(true, x, y) if cell == "0"
        @opp_camp = Camp.new(false, x, y) if cell == "1"

        camp = "#{x} #{y}"
        @grid.n4(camp).each do |next_to_camp|
          @grid.remove_connection(next_to_camp, camp)
        end
      end
    end

    nil
  end
end
