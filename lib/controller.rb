Camp = Struct.new(:my, :x, :y) do
  def node
    @node ||= "#{x} #{y}"
  end
end
Inventory = Struct.new(:plum, :lemon, :apple, :banana, :iron, :wood) do
  def can_afford?(cost_hash)
    cost_hash.all? { |type, count| send(type.downcase) >= count }
  end
end
Cell = Struct.new(:x, :y, :worker, :tree)
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
    :cells, :trees, :workers

  # Trees differ in cooldown and health as follows: | TRAIN moveSpeed carryCapacity harvestPower chopPower
  #                     PLUM	LEMON	APPLE	BANANA
  # Cooldown	          8	    8	    9	    6
  # Cooldown near water	3	    3	    2	    4
  # Health (size 1)	    6	    6	    11  	3
  # Health (size 2)	    8	    8	    14	  4
  # Health (size 3)	    10	  10  	17	  5
  # Health (size 4)	    12	  12	  20	  6
  TREE_STATS = {
    "PLUM" => {cd: 8, cdw: 3, 1 => 6, 2 => 8, 3 => 10, 4 => 12}, # MOVE
    "LEMON" => {cd: 8, cdw: 3, 1 => 6, 2 => 8, 3 => 10, 4 => 12}, # CARRY
    "APPLE" => {cd: 9, cdw: 2, 1 => 11, 2 => 14, 3 => 17, 4 => 20}, # HARVEST
    "BANANA" => {cd: 6, cdw: 4, 1 => 3, 2 => 4, 3 => 5, 4 => 6} # -
  }

  # @param field String # multiline heredoc style
  def initialize(field:)
    @field = field
    init_grid
  end

  def inspect
    "#<#{self.class} field=#{@field.inspect}>"
  end

  # @param turn Integer
  # @param input String # the raw as-is multiline input provided by game
  # @return String
  def call(turn:, input:)
    @turn = turn
    debug(@input = input)
    init_turn_variables!

    @commands = []

    # hardcoded experiments
    # return "MOVE 0 8 5" if turn == 1
    # return "MOVE 0 8 5" if turn == 2
    # return "PICK 0 LEMON" if turn == 3

    if my_workers.size < 2
      if my_inventory.can_afford?(best_worker_cost)
        @commands << "TRAIN 2 4 0 3" # "TRAIN 1 1 1 0"
      end
    end

    # Initial boosting
    if my_workers.size == 1
      # TODO, maybe check if a cheap helper can be afforded and useful, usually should be

      lemon_production_near_camp_per_turn = nodes_within_3_of_camp.sum do |near_node|
        cell = cells[near_node]
        next 0 if cell.nil? || cell.tree.nil? || cell.tree.type != "LEMON" || cell.tree.size < 4

        wet_nodes.include?(near_node) ? (1/8.0) : (1/3.0)
      end

      if lemon_production_near_camp_per_turn < (11/24.0) # one watered and one regular or 4 regular
        wet_path = wet_nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
          .map { shortest_path(my_camp.node, _1) }
          .min_by { _1.size }

        if wet_path
          handle_lemon_planting_at_end_of(my_workers.first, wet_path)

          return (result = @commands.join("; ")) == "" ? "WAIT" : result
        end

        regular_path = nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
          .map { shortest_path(my_camp.node, _1) }
          .min_by { _1.size }

        if regular_path
          handle_lemon_planting_at_end_of(my_workers.first, regular_path )

          return (result = @commands.join("; ")) == "" ? "WAIT" : result
        end
      end
    end
    # MULTI worker moneymaking
    my_workers.each do |worker|
      if worker.carry_banana > 0 && grid.n4(my_camp.node).include?(worker.node) && cells[worker.node].tree.nil?
        @commands << "PLANT #{worker.id} BANANA"
      elsif worker.full?
        home_paths = grid.n4(my_camp.node).map { [_1, shortest_path(worker.node, _1)]}
        next_to_home_node, path = home_paths.sort_by { |node, path| grid.path_length(path) }.first

        if next_to_home_node && path.size == 1 # let's deposit!
          @commands << "DROP #{worker.id}"
        elsif
          @commands << "MOVE #{worker.id} #{next_to_home_node}"
        end
      else
        fruit_paths = trees.select(&:fruit?).map do
          path = shortest_path(worker.node, _1.node)
          score = fruit_tree_score(worker, _1, path)

          [_1, path, score]
        end

        closest_fruit_tree, path, _score = fruit_paths.max_by { |_, _, score| score }

        if closest_fruit_tree && path.size == 1 # let's harvest!
          @commands << "HARVEST #{worker.id}"
        elsif closest_fruit_tree
          @commands << "MOVE #{worker.id} #{closest_fruit_tree.node}"
        end
      end
    end

    (result = @commands.join("; ")) == "" ? "WAIT" : result
  end
  # Each turn you can print any number of commands, separated by ;.
  # MOVE id x y Move troll id to cell (x, y).
  # HARVEST id Make troll id harvest on its current cell.
  # PLANT id type Make troll id plant a type on its current cell: PLUM, LEMON, APPLE or BANANA.
  # CHOP id Make troll id chop on its current cell.
  # PICK id type Make troll id pick one type from the shack: PLUM, LEMON, APPLE or BANANA.
  # DROP id Make troll id drop all carried items at the shack.
  # TRAIN moveSpeed carryCapacity harvestPower chopPower | Train a new troll with the given attributes.
  # MINE id Make troll id mine a nearby IRON.
  # WAIT to do nothing.
  # MSG text to display a message in the replay.

  private

  def handle_lemon_planting_at_end_of(worker, path)
    if worker.node == path.last && worker.carry_lemon.positive?
      @commands << "PLANT #{worker.id} LEMON"
    elsif worker.carry_lemon.positive?
      @commands << "MOVE #{worker.id} #{path.last}"
    elsif worker.node == path[1] && worker.carry_lemon.zero?
      @commands << "PICK #{worker.id} LEMON"
    else # as in no lemon in hand, go to near camp
      @commands << "MOVE #{worker.id} #{path[1]}"
    end

    nil
  end

  # @return Numeric
  def fruit_tree_score(worker, tree, path)
    distance = grid.path_length(path)

    score = 0
    score -= distance * 100
    score += case tree.type
      when "BANANA"
        90
      when "PLUM", "LEMON"
        60
      else
        0
      end
    score += tree.fruits

    score
  end

  # @return Hash {"PLUM" => 3, "LEMON" => 3, "APPLE" => 3}
  def cheapest_worker_cost
    existing_workers = my_workers.size

    {
      "PLUM" => existing_workers + 1, "LEMON" => existing_workers + 1, "APPLE" => existing_workers + 1,
      "IRON" => existing_workers
    }
  end

  def best_worker_cost
    # TRAIN moveSpeed carryCapacity harvestPower chopPower
    # "TRAIN 2 4 0 3"

    existing_workers = my_workers.size

    {
      "PLUM" => existing_workers + 4, "LEMON" => existing_workers + 16, "APPLE" => existing_workers,
      "IRON" => existing_workers + 9
    }
  end

  def my_workers
    @my_workers ||= {}
    return @my_workers[turn] if @my_workers.key?(turn)
    @my_workers[turn] = workers.select(&:my?)
  end

  def init_turn_variables!
    lines = input.split("\n")

    @my_inventory = Inventory.new(*lines.shift.split.map(&:to_i))
    @opp_inventory = Inventory.new(*lines.shift.split.map(&:to_i))

    @cells = {}

    @trees = []
    lines.shift.to_i.times do
      type, x, y, size, health, fruits, cooldown = lines.shift.split.map { _1[0].match?(%r'\d') ? _1.to_i : _1 }
      tree = Tree.new(type, x, y, size, health, fruits, cooldown)
      @trees << tree
      @cells["#{x} #{y}"] ||= Cell.new(x, y, nil, nil)
      @cells["#{x} #{y}"].tree = tree
    end

    @workers = []
    lines.shift.to_i.times do
      id, player, x, y, movement_speed, carry_capacity, harvest_power, chop_power, carry_plum, carry_lemon, carry_apple, carry_banana, carry_iron, carry_wood = lines.shift.split.map(&:to_i)

      worker = Worker.new(
        id, player, x, y,
        movement_speed, carry_capacity, harvest_power, chop_power,
        carry_plum, carry_lemon, carry_apple, carry_banana, carry_iron, carry_wood
      )
      @workers << worker

      @cells["#{x} #{y}"] ||= Cell.new(x, y, nil, nil)
      @cells["#{x} #{y}"].worker = worker
    end
  end

  # Grid init is a simple fill, bet we make caps leave-only (and maybe rocks in future leagues)
  def init_grid
    lines = field.split("\n")
    @grid = Grid.new(lines.first.size, lines.size, fill: true)

    lines.each_with_index do |line, y|
      line.split("").each_with_index do |cell, x|
        node = "#{x} #{y}"
        # . for GRASS, ~ for WATER, # for ROCK, + for IRON, 0 for your own SHACK, 1 for your opponent's SHACK.
        @grid.remove_cell(node) if %w[~ # +].include?(cell)

        grass_nodes << node if cell == "."
        water_nodes << node if cell == "~"

        @my_camp = Camp.new(true, x, y) if cell == "0"
        @opp_camp = Camp.new(false, x, y) if cell == "1"

        if cell == "0" || cell == "1"
          @grid.n4(node).each do |next_to_camp|
            @grid.remove_connection(next_to_camp, node)
          end
        end
      end
    end

    grass_nodes.each do |grass_node|
      wet_nodes << grass_node if @grid.n4(grass_node).any? { water_nodes.include?(_1) }
    end

    #== precrunching shortest paths between all grass nodes and from camp to grass nodes
    grass_nodes.each do |grass_node|
      shortest_path(my_camp.node, grass_node)
    end

    grid.n4(my_camp.node).each do |node|
      grass_nodes.each do |grass_node|
        shortest_path(node, grass_node)
      end
    end
    #==

    wet_nodes_within_3_of_camp

    nil
  end

  def shortest_path(from, to)
    key = [from, to]
    return shortest_paths[key] if shortest_paths.key?(key)
    path = grid.shortest_path(*key)

    shortest_paths[key.reverse] = path.reverse
    shortest_paths[key] = path
  end

  # @return Hash # keys are array of start-end node pairs
  def shortest_paths
    @shortest_paths ||= {}
  end

  # Distance up to 3 is special because water is that much more effective
  #
  # @return Set
  def wet_nodes_within_3_of_camp
    @wet_nodes_within_3_of_camp ||= nodes_within_3_of_camp & wet_nodes
  end

  def nodes_within_3_of_camp
    @nodes_within_3_of_camp ||= grass_nodes.select do |grass_node|
      shortest_path(my_camp.node, grass_node).size <= 4
    end.to_set
  end

  # @return Set
  def wet_nodes
    @wet_nodes ||= Set.new
  end

  def grass_nodes
    @grass_nodes ||= Set.new
  end

  def water_nodes
    @water_nodes ||= Set.new
  end
end
