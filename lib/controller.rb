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
Tree = Struct.new(:type, :x, :y, :size, :health, :fruits, :cooldown, :period) do
  def node
    @node ||= "#{x} #{y}"
  end

  def type?(desired_type)
    type == desired_type
  end

  def fruit?
    fruits >= 1
  end

  def grown?
    size == 4
  end

  #  # lower is better. Ideally 0 - if the worker is already there. Can be negative is several fruits
  #
  # @return Numeric
  def turns_till_fruit(worker, path_to)
    distance_penalty = path_to.size
    return distance_penalty if fruits.positive?

    cooldown_penalty = (4 - size) * period + cooldown

    [distance_penalty, cooldown_penalty].max
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

    # Initial boosting has one goal - be able to afford an excellent chopper worker.
    # It consists of 3 subgoals:
    #  1. Reach 17 lemons
    #  2. 10 iron
    #  3. 5 plums (easy)
    if my_workers.size == 1 && @commands.none? { _1.start_with?("TRAIN") }
      # TODO, maybe check if a cheap helper can be afforded and useful, usually should be

      ensure_sufficient_lemon_growth if my_inventory.lemon < 17
      return @commands.join("; ") if @commands.any?

      ensure_sufficient_plum_growth if my_inventory.plum < 5
      return @commands.join("; ") if @commands.any?

      gather_iron if my_inventory.iron < 10
      return @commands.join("; ") if @commands.any?

      gather_initial_fruit(my_workers.first, "LEMON", _max_wait = 5) if my_inventory.lemon < 17
      return @commands.join("; ") if @commands.any?

      gather_initial_fruit(my_workers.first, "PLUM", _max_wait = 5) if my_inventory.plum < 5
      return @commands.join("; ") if @commands.any?

      gather_initial_fruit(my_workers.first, "LEMON", _max_wait = 30) if my_inventory.lemon < 17
      return @commands.join("; ") if @commands.any?
    end

    debug("== OK, time to get a chopper and start chopping!")
    organize_chopping if my_workers.size > 1
    organize_chopper_helpers

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

  def ensure_sufficient_lemon_growth
    expected_lemon_production_near_camp_per_turn = nodes_within_3_of_camp.sum do |near_node|
      cell = cells[near_node]
      next 0 if cell.nil? || cell.tree.nil? || cell.tree.type != "LEMON"

      wet_nodes.include?(near_node) ? (1/8.0) : (1/3.0)
    end
    debug "== Eventual Lemon production near camp per turn #{expected_lemon_production_near_camp_per_turn}"

    return if expected_lemon_production_near_camp_per_turn >= (11/24.0) # 0.45; one watered and one regular or 4 regular

    wet_path = wet_nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
      .map { shortest_path(my_camp.node, _1) }
      .min_by { _1.size }

    if wet_path
      handle_planting_at_end_of(my_workers.first, wet_path, "LEMON")
      return
    end

    regular_path, _ = nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
      .map { [shortest_path(my_camp.node, _1), shortest_path(my_workers.first.node, _1)] }
      .min_by { _1.size + _2.size }

    if regular_path
      handle_planting_at_end_of(my_workers.first, regular_path, "LEMON")
      return
    end
  end

  def ensure_sufficient_plum_growth
    expected_plum_production_near_camp_per_turn = nodes_within_3_of_camp.sum do |near_node|
      cell = cells[near_node]
      next 0 if cell.nil? || cell.tree.nil? || cell.tree.type != "PLUM"

      wet_nodes.include?(near_node) ? (1/8.0) : (1/3.0)
    end
    debug "== Eventual Plum production near camp per turn #{expected_plum_production_near_camp_per_turn}"

    return if expected_plum_production_near_camp_per_turn >= (1/8.0) # one tree on any wetness is sufficient

    wet_path = wet_nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
      .map { shortest_path(my_camp.node, _1) }
      .min_by { _1.size }

    if wet_path
      handle_planting_at_end_of(my_workers.first, wet_path, "PLUM")
      return
    end

    regular_path, _ = nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
      .map { [shortest_path(my_camp.node, _1), shortest_path(my_workers.first.node, _1)] }
      .min_by { _1.size + _2.size }

    if regular_path
      handle_planting_at_end_of(my_workers.first, regular_path, "PLUM")
      return
    end
  end

  def handle_planting_at_end_of(worker, path, tree_type)
    getter = "carry_#{tree_type.downcase}"

    if worker.node == path.last && worker.send(getter).positive?
      @commands << "PLANT #{worker.id} #{tree_type}"
    elsif worker.send(getter).positive?
      @commands << "MOVE #{worker.id} #{path.last}"
    elsif worker.node == path[1] && worker.send(getter).zero?
      @commands << "PICK #{worker.id} #{tree_type}"
    else # as in no lemon in hand, go to near camp
      @commands << "MOVE #{worker.id} #{path[1]}"
    end

    nil
  end

  def gather_iron
    # noop for now!
  end

  def gather_initial_fruit(worker, fruit_type, max_wait)
    if worker.full? && grid.n4(my_camp.node).include?(worker.node)
      @commands << "DROP #{worker.id}"
    elsif worker.full? # go to dropoff
      home_paths = grid.n4(my_camp.node).map { [_1, shortest_path(worker.node, _1)]}
      next_to_home_node, path = home_paths.sort_by { |_node, path| path.size }.first

      @commands << "MOVE #{worker.id} #{next_to_home_node}"
    elsif cells[worker.node]&.tree&.type == fruit_type && cells[worker.node]&.tree&.fruit? # at a tree already!
      @commands << "HARVEST #{worker.id}"
    else # gotta detect and go to a good candidate tree
      path_to_tree, turns_till = nodes_within_3_of_camp
        .select { cells[_1]&.tree && cells[_1].tree.type?(fruit_type) }
        .map do |node|
          path = shortest_path(worker.node, node)
          [path, cells[node].tree.turns_till_fruit(worker, path)]
        end.select { _2 <= max_wait }.min_by { |_path, turns_till| turns_till }

      if path_to_tree.nil?
        debug("== No #{fruit_type} trees qualify for early harvesting with a wait time of #{max_wait}")
        return
      end

      @commands << "MSG turns till #{fruit_type} #{turns_till}"
      @commands << "MOVE #{worker.id} #{path_to_tree.last}"
    end
  end

  def organize_chopping
    chopper = my_workers.max_by(&:carry_capacity)

    # 0. unload if carrying wood for some reason
    if chopper.carry_wood.positive?
      closest_camp_n4 = grid.n4(my_camp.node).min_by { shortest_path(chopper.node, _1).size }

      return go_and_drop(chopper, closest_camp_n4)
    end

    # 1. clear seed node if it does not have a banana on it
    if cells[seed_node]&.tree && !cells[seed_node].tree.type?("BANANA")
      return go_and_chop(chopper, seed_node)
    end

    # 2. seed is open, chop bananas, then grown trees next to seed, finally anything
    grown_banana_nodes = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree && cells[_1].tree.grown? && cells[_1].tree.type?("BANANA") }

    if grown_banana_nodes.any?
      closest = grown_banana_nodes.min_by { shortest_path(chopper.node, _1).size }
      return go_and_chop(chopper, closest)
    end

    grown_next_to_seed = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree && cells[_1].tree.grown? && grid.neighbors(seed_node).include?(_1) }

    if grown_next_to_seed.any?
      closest = grown_next_to_seed.min_by { shortest_path(chopper.node, _1).size }
      return go_and_chop(chopper, closest)
    end

    grown = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree && cells[_1].tree.grown? }

    if grown.any?
      closest = grown.min_by { shortest_path(chopper.node, _1).size }
      return go_and_chop(chopper, closest)
    end

    debug("== Hmm, no choppable trees, guess lets go to soonest choppable")

    growing = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree }

    if growing.any?
      growest = growing.min_by { cells[_1].tree.turns_till_fruit(chopper, shortest_path(chopper.node, _1)) }

      if chopper.node == growest # already there!
        # @commands << "WAIT #{chopper.id}"
        debug("== Chopper waiting on a growing tree")
      else # go if not there
        path = shortest_path(chopper.node, growest)
        @commands << "MOVE #{chopper.id} #{path[chopper.movement_speed] || path.last}"
      end
      return
    end

    debug("== Hmmmm, no choppable nor growing trees, helper slacking off?")
  end

  def organize_chopper_helpers
    servant = my_workers.min_by(&:carry_capacity)

    [servant].each do |worker|
      if worker.full? && worker.carry_banana.zero?
        closest_camp_n4 = grid.n4(my_camp.node).min_by { shortest_path(worker.node, _1).size }

        go_and_drop(worker, closest_camp_n4)
        next
      end

      if worker.carry_banana.positive?
        # 1. seek to plant a banana on seed node
        if cells[seed_node]&.tree.nil?
          go_and_plant(worker, seed_node, "BANANA")
          next
        end

        # 2. seek to plant next to seed node
        closest = nodes_within_3_of_camp_except_seed
          .select { cells[_1]&.tree.nil? }
          .min_by { shortest_path(worker.node, _1).size + shortest_path(my_camp.node, _1).size }

        if closest
          go_and_plant(worker, closest, "BANANA")
          next
        end
      end

      # not carrying a banana, should get one
      seeding_bananas =
        cells[seed_node]&.tree&.type?("BANANA") &&
        cells[seed_node]&.tree&.turns_till_fruit(worker, shortest_path(worker.node, seed_node)) < 5

      if seeding_bananas
        go_and_harvest(worker, seed_node)
        next
      elsif my_inventory.banana.positive?
        closest_camp_n4 = grid.n4(my_camp.node).min_by { shortest_path(worker.node, _1).size }
        go_and_pick(worker, closest_camp_n4, "BANANA")
        next
      elsif (banana_nodes = cells.select { |node, cell| cell&.tree&.type?("BANANA") }).any?
        closest, _cell = banana_nodes.min_by { |node, cell| cell.tree.turns_till_fruit(worker, shortest_path(worker.node, node)) }

        if closest
          go_and_harvest(worker, closest)
          next
        end
      else
        debug("== Hmm, no banana trees on map?")
      end
    end
  end

  def go_and_harvest(worker, node)
    if worker.node == node # already there!
      @commands << "HARVEST #{worker.id}"
    else # go if not there
      path = shortest_path(worker.node, node)
      @commands << "MOVE #{worker.id} #{path[worker.movement_speed] || path.last}"
    end
  end

  def go_and_pick(worker, node, type)
    if worker.node == node # already there!
      @commands << "PICK #{worker.id} #{type}"
    else # go if not there
      path = shortest_path(worker.node, node)
      @commands << "MOVE #{worker.id} #{path[worker.movement_speed] || path.last}"
    end
  end

  def go_and_plant(worker, node, type)
    if worker.node == node # already there!
      @commands << "PLANT #{worker.id} #{type}"
    else # go if not there
      path = shortest_path(worker.node, node)
      @commands << "MOVE #{worker.id} #{path[worker.movement_speed] || path.last}"
    end
  end

  def go_and_chop(chopper, node)
    if chopper.node == node # already there!
      @commands << "CHOP #{chopper.id}"
    else # go if not there
      path = shortest_path(chopper.node, node)
      @commands << "MOVE #{chopper.id} #{path[chopper.movement_speed] || path.last}"
    end
  end

  def go_and_drop(worker, node)
    if grid.n4(my_camp.node).include?(worker.node) # already next to camp!
      @commands << "DROP #{worker.id}"
    else
      path = shortest_path(worker.node, node)
      @commands << "MOVE #{worker.id} #{path[worker.movement_speed] || path.last}"
    end
  end

  # @return Numeric
  def fruit_tree_score(worker, tree, path)
    distance = path.size

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
    # "TRAIN 2 4 0 3" # 5, 17, 0, 10 costs

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

  def tree_period_mapping
    @tree_period_mapping ||= {
      dry: {"PLUM" => 8, "LEMON" => 8, "APPLE" => 9, "BANANA" => 6},
      wet: {"PLUM" => 3, "LEMON" => 3, "APPLE" => 2, "BANANA" => 4}
    }
  end

  def init_turn_variables!
    lines = input.split("\n")

    @my_inventory = Inventory.new(*lines.shift.split.map(&:to_i))
    @opp_inventory = Inventory.new(*lines.shift.split.map(&:to_i))

    @cells = {}

    @trees = []
    lines.shift.to_i.times do
      type, x, y, size, health, fruits, cooldown = lines.shift.split.map { _1[0].match?(%r'\d') ? _1.to_i : _1 }

      period = wet_nodes.include?("#{x} #{y}") ? tree_period_mapping.dig(:wet, type) : tree_period_mapping.dig(:dry, type)
      tree = Tree.new(type, x, y, size, health, fruits, cooldown, period)
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
    seed_node

    grass_nodes.each do |grass_node|
      shortest_path(grass_node, seed_node)
    end

    nodes_within_3_of_camp_except_seed

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

  def nodes_within_3_of_camp_except_seed
    @nodes_within_3_of_camp_except_seed ||= nodes_within_3_of_camp - [seed_node]
  end

  # A special node either next to water with 2+ neighboring cells close to camp or a next-to-camp cell
  # where a banana for continuous replanting will be planted and never chopped
  def seed_node
    @seed_node ||=
      if wet_nodes_within_3_of_camp.any?
        wet_nodes_within_3_of_camp.max_by { (grid.neighbors(_1) & nodes_within_3_of_camp).size }
      else
        nodes_within_3_of_camp.max_by { (grid.neighbors(_1) & nodes_within_3_of_camp).size }
      end
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
