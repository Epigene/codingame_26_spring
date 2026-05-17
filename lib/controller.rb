Camp = Struct.new(:my, :x, :y) do
  def node
    @node ||= "#{x} #{y}"
  end
end
Inventory = Struct.new(:plum, :lemon, :apple, :banana, :iron, :wood) do
  def can_afford?(cost_hash)
    cost_hash.all? { |type, count| send(type.downcase) >= count }
  end

  # @return [String, nil] # "1 1 1 1"
  def best_intermediate_worker(existing_worker_count)
    tiers = [
      best_affordable_train_tier("PLUM", 3, existing_worker_count),
      carry = best_affordable_train_tier("LEMON", 2, existing_worker_count),
      best_affordable_train_tier("APPLE", carry, existing_worker_count),
      best_affordable_train_tier("IRON", carry, existing_worker_count)
    ]

    return if tiers.any?(&:zero?)

    tiers.join(" ")
  end

  # @type LEMON etc. Caller neets to know that PLUM == movespeed etc.
  def best_affordable_train_tier(type, allowed_max, existing_worker_count)
    store = send(type.downcase)
    if store >= (existing_worker_count+(3**2))
      [allowed_max, 3].min
    elsif store >= (existing_worker_count+(2**2))
      [allowed_max, 2].min
    elsif store >= (existing_worker_count+1)
      1
    else
      0
    end
  end
end
Cell = Struct.new(:x, :y, :worker, :tree)
TREE_HEALTH_MATRIX = {
  "PLUM" => {increment: 2, 1=> 6, 2=> 8, 3 => 10, 4 => 12},
  "LEMON" => {increment: 2, 1=> 6, 2=> 8, 3 => 10, 4 => 12},
  "APPLE" => {increment: 3, 1=> 11, 2=> 14, 3 => 17, 4 => 20},
  "BANANA" => {increment: 1, 1=> 3, 2=> 4, 3 => 5, 4 => 6}
}.freeze
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

  def turns_till_size(desired_size)
    return 0 if size >= desired_size

    diff = desired_size - size
    growth_periods = diff - 1
    [growth_periods, 0].max * period + cooldown
  end

  def damaged?
    health < TREE_HEALTH_MATRIX.dig(type, size)
  end

  # Smart, assuming continious chopping and any outstanding growth, how many turns it will take to fell
  # @return Integer
  def chop_turns(chop_speed)
    return 99 if chop_speed < 1
    return 1 if health <= chop_speed

    copy = dup
    turns = 1

    loop do
      # apply chop
      copy.health -= chop_speed
      return turns if copy.health <= 0

      # apply HP increase from growth
      copy.apply_turn

      turns += 1
    end
  end

  # This should only be called on dupes to simulate turns passing and tree growing
  def apply_turn
    self.cooldown -= 1
    return if cooldown.positive?

    self.cooldown = period
    if size < 4
      self.size += 1
      self.health += TREE_HEALTH_MATRIX.dig(type, :increment)
    end
  end
end
Worker = Struct.new(:id, :player, :x, :y,
  :move_speed, :carry_capacity, :harvest_power, :chop_power,
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

  def can_chop?
    chop_power.positive?
  end
end
Plan = Struct.new(:name, :worker_id, :type, :node, :weight) do
  # @return String
  def command
    return "#{name} #{worker_id} #{node}" if name == "MOVE"

    [
      name,
      worker_id,
      type
    ].compact.join(" ")
  end

  def weight
    @weight || 0
  end
end

class Controller
  attr_reader :field, :turn, :input, :grid,
    :my_camp, :opp_camp, :my_inventory, :opp_inventory,
    :cells, :trees,
    :workers, :helper, :inter, :chopper,
    :training, :messages, :plans

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
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @field = field
    init_grid
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    debug("|| Field init took #{((t1 - t0) * 1000).round}ms")
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
    @training = nil
    @messages = []
    @plans = {} # worker-id-keyed

    # hardcoded experiments
    # return "MOVE 0 8 5" if turn == 1
    # return "MOVE 0 8 5" if turn == 2
    # return "PICK 0 LEMON" if turn == 3

    if turn <= 1
      # 5, 17, 0, 10
      turns_till_chopper =
        -[my_inventory.plum - 5, 0].min * 5 +
        -[my_inventory.lemon - 17, 0].min * 5 +
        -[my_inventory.iron - 10, 0].min * shortest_path_to_mining.size * 2

      # in how many turns is it OK to scale straight to chopper. Can probably go lower than 70, maybe 50.
      if turns_till_chopper > 70
        potential_worker = my_inventory.best_intermediate_worker(my_workers.size)
        if potential_worker
          @training = "TRAIN #{potential_worker}"
        end
      end
    end

    if chopper.nil? && my_inventory.can_afford?(best_worker_cost)
      debug("== OK, time to get a chopper and start chopping!")
      @training = "TRAIN 2 4 0 3" # "TRAIN 1 1 1 0"
    end

    organize_chopping if chopper
    organize_intermediate(inter) if inter
    organize_helper(helper)

    result = [
      messages.any? ? "MSG #{messages.join(", ")}" : nil,
      training,
      *plans.values.sort_by { -_1.weight }.map(&:command)
    ].compact.join("; ")

    result == "" ? "WAIT" : result
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

  def organize_intermediate(worker)
    (my_inventory.lemon < best_worker_cost["LEMON"] && gather_initial_fruit(worker, "LEMON", 1)) ||
      (my_inventory.iron < best_worker_cost["IRON"] && gather_iron(worker))
  end

  def organize_helper(worker)
    # Initial boosting has one goal - be able to afford an excellent chopper worker.
    # It consists of 3 subgoals:
    #  1. Reach 17 lemons
    #  2. 10 iron
    #  3. 5 plums (easy)
    if chopper.nil? && !training.to_s.match?(%r'TRAIN \d+ \d+ 0')
      debug("== Helper will help scale to chopper")
      (my_inventory.lemon < best_worker_cost["LEMON"] && ensure_sufficient_lemon_growth(worker)) ||
        (my_inventory.plum < best_worker_cost["PLUM"] && ensure_sufficient_plum_growth(worker)) ||
        (my_inventory.lemon < best_worker_cost["LEMON"] && gather_initial_fruit(worker, "LEMON", 5)) ||
        (my_inventory.plum < best_worker_cost["PLUM"] && gather_initial_fruit(worker, "PLUM", 5)) ||
        (my_inventory.iron < best_worker_cost["IRON"] && gather_iron(worker)) ||
        (my_inventory.lemon < best_worker_cost["LEMON"] && gather_initial_fruit(worker, "LEMON", 30))
    end
    return if plans[worker.id]

    # == Regular helping starts ==

    if worker.full? && worker.carry_banana.zero?
      closest_camp_n4 = dropoff_nodes.min_by { shortest_path(worker.node, _1).size }
      return go_and_drop(worker, closest_camp_n4)
    end

    # Get off square chopper wants to get to
    if plans.values.any? { _1.node == worker.node }
      # prefer an empty nearby square (if any) if carrying a seed banana
      if worker.full? && worker.carry_banana.positive?
        nearby_plantable_node = grid.neighbors(worker.node)
          .select { cells[_1]&.tree.nil? }
          .min_by { shortest_path(my_camp.node, _1) }

        return go_and_plant(worker, nearby_plantable_node, "BANANA") if nearby_plantable_node

        nearby_tree_node = grid.neighbors(worker.node)
          .select { cells[_1]&.tree }
          .quick_min_by { cells[_1].tree.turns_till_size(4) }

        return go_and_chop(worker, nearby_tree_node) if nearby_tree_node
      end

      # otherwise worker is not carrying anything
      nearby_tree_node = grid.neighbors(worker.node)
        .select { cells[_1]&.tree }
        .quick_min_by { cells[_1].tree.turns_till_size(4) }
      return go_and_chop(worker, nearby_tree_node) if nearby_tree_node

      nearby_empty_node = grid.neighbors(worker.node)
        .select { cells[_1]&.tree.nil? }
        .min_by { shortest_path(my_camp.node, _1) }
      return go_and_chop(worker, nearby_empty_node) if nearby_empty_node
    end

    if turn > 285
      # TODO, noop for now, but could chop or pre-chop something at the tail-end
      # Definitely no sense planting anything anymore
      return
    end

    if worker.carry_banana.positive?
      # 1. seek to plant a banana on seed node
      if cells[seed_node]&.tree.nil?
        return go_and_plant(worker, seed_node, "BANANA")
      end

      # 2. seek to plant next to seed node
      closest = nodes_within_3_of_camp_except_seed
        .select { cells[_1]&.tree.nil? }
        .min_by { shortest_path(worker.node, _1).size + shortest_path(my_camp.node, _1).size }

      if closest
        return go_and_plant(worker, closest, "BANANA")
      end
    end

    # not carrying a banana, should get one
    seeding_bananas =
      cells[seed_node]&.tree&.type?("BANANA") &&
      cells[seed_node]&.tree&.turns_till_fruit(worker, shortest_path(worker.node, seed_node)) < 5

    if seeding_bananas
      return go_and_harvest(worker, seed_node)
    elsif my_inventory.banana.positive?
      closest_dropoff = dropoff_nodes.min_by { shortest_path(worker.node, _1).size }
      return go_and_pick(worker, closest_dropoff, "BANANA")
    elsif (banana_nodes = cells.select { |node, cell| cell&.tree&.type?("BANANA") }).any?
      closest, _cell = banana_nodes.min_by do |node, cell|
        cell.tree.turns_till_fruit(worker, shortest_path(worker.node, node))
      end

      if closest
        return go_and_harvest(worker, closest)
      end
    else
      debug("== Hmm, no banana trees on map?")
    end
  end

  def ensure_sufficient_lemon_growth(worker)
    expected_lemon_production_near_camp_per_turn = nodes_within_3_of_camp.sum do |near_node|
      cell = cells[near_node]
      next 0 if cell.nil? || cell.tree.nil? || cell.tree.type != "LEMON"

      wet_nodes.include?(near_node) ? (1/3.0) : (1/8.0)
    end
    debug "== Eventual Lemon production near camp per turn #{expected_lemon_production_near_camp_per_turn}"

    return if expected_lemon_production_near_camp_per_turn >= (2/8.0) # one watered or 2 regular

    wet_path = wet_nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
      .map { shortest_path(my_camp.node, _1) }
      .min_by { _1.size }

    if wet_path
      return handle_planting_at_end_of(worker, wet_path, "LEMON")
    end

    regular_path, _ = nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
      .map { [shortest_path(my_camp.node, _1), shortest_path(worker.node, _1)] }
      .min_by { _1.size + _2.size }

    if regular_path
      return handle_planting_at_end_of(worker, regular_path, "LEMON")
    end
  end

  def ensure_sufficient_plum_growth(worker)
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
      return handle_planting_at_end_of(worker, wet_path, "PLUM")
    end

    regular_path, _ = nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
      .map { [shortest_path(my_camp.node, _1), shortest_path(worker.node, _1)] }
      .min_by { _1.size + _2.size }

    if regular_path
      return handle_planting_at_end_of(worker, regular_path, "PLUM")
    end
  end

  # @path Array<Node> # starts at camp and ends at desired tree node
  def handle_planting_at_end_of(worker, path, tree_type)
    getter = "carry_#{tree_type.downcase}"

    if worker.node == path.last && worker.send(getter).positive?
      plans[worker.id] = Plan.new("PLANT", worker.id, tree_type)
    elsif worker.send(getter).positive?
      worker_path = shortest_path(worker.node, path.last)
      plans[worker.id] = Plan.new("MOVE", worker.id, nil, worker_path[worker.move_speed] || worker_path.last)
    elsif worker.node == path[1] && worker.send(getter).zero? && my_inventory.send(tree_type.downcase).positive?
      plans[worker.id] = Plan.new("PICK", worker.id, tree_type)
    elsif my_inventory.send(tree_type.downcase).positive? # as in no lemon in hand, go to near camp
      worker_path = shortest_path(worker.node, path[1])
      plans[worker.id] = Plan.new("MOVE", worker.id, nil, worker_path[worker.move_speed] || worker_path.last)
    end

    true
  end

  def gather_iron(worker)
    if worker.full?
      closest_dropoff = dropoff_nodes.min_by { shortest_path(worker.node, _1).size }
      return go_and_drop(worker, closest_dropoff)
    end

    closest_mine = mining_nodes.min_by { shortest_path(worker.node, _1).size }
    return go_and_mine(worker, closest_mine)
  end

  def gather_initial_fruit(worker, fruit_type, max_wait)
    if worker.full? && dropoff_nodes.include?(worker.node)
      plans[worker.id] = Plan.new("DROP", worker.id)
    elsif worker.full? # go to dropoff
      home_paths = dropoff_nodes.map { [_1, shortest_path(worker.node, _1)]}
      next_to_home_node, path = home_paths.sort_by { |_node, path| path.size }.first

      plans[worker.id] = Plan.new("MOVE", worker.id, nil, next_to_home_node)
    elsif cells[worker.node]&.tree&.type == fruit_type && cells[worker.node]&.tree&.fruit? # at a tree already!
      plans[worker.id] = Plan.new("HARVEST", worker.id)
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

      messages << "turns till #{fruit_type} #{turns_till}"
      plans[worker.id] = Plan.new("MOVE", worker.id, nil, path_to_tree.last)
    end
  end

  def organize_chopping
    # 0. unload if carrying wood for some reason
    if chopper.carry_wood.positive?
      closest_camp_n4 = dropoff_nodes.min_by { shortest_path(chopper.node, _1).size }

      return go_and_drop(chopper, closest_camp_n4)
    end

    # WAR, seek to fight over chopping if opp within 2 turns can be cought
    opp_workers_chopping = workers.select { !_1.my? }.select { _1.can_chop? && cells[_1.node]&.tree&.damaged? }
    if opp_workers_chopping.any?
      chops = opp_workers_chopping.map do |opp_worker|
        tree = cells[opp_worker.node].tree
        path = shortest_path(chopper.node, opp_worker.node)
        turns_to_reach = ((path.size - 1) / chopper.move_speed.to_f).ceil
        turns_to_fell = tree.chop_turns(opp_worker.chop_power)
        [path, turns_to_reach, turns_to_fell]
      end

      interceptable_chops = chops.select { |p, to_reach, to_fell| to_reach <= 2 && (to_reach + 1) <= to_fell }
      if interceptable_chops.any?
        path, _, _ = interceptable_chops.quick_max_by { |p, to_reach, to_fell| cells[p.last].tree.size }

        messages << "chop warz"
        return go_and_chop(chopper, path.last)
      end
    end

    # 0, if outside base squares (beelined previously), continue on to nearest grown tree
    if !nodes_within_3_of_camp.include?(chopper.node)
      closest_grown_tree = trees.select(&:grown?).min_by { shortest_path(chopper.node, _1.node).size }
      if closest_grown_tree
        messages << "beeline"
        return go_and_chop(chopper, closest_grown_tree.node)
      end
    end

    # 0, ENDGAME CLEAR
    if turn > 287
      nearby_bananas = nodes_within_3_of_camp
        .select { cells[_1]&.tree && cells[_1].tree.grown? && cells[_1].tree.type?("BANANA") }

      if nearby_bananas.any?
        node = nearby_bananas.quick_min_by { shortest_path(chopper.node, _1).size }
        messages << "fullclear"
        go_and_chop(chopper, node)
        return
      end

      nearby_non_bananas = nodes_within_3_of_camp
        .select { cells[_1]&.tree && cells[_1].tree.grown? && !cells[_1].tree.type?("BANANA") }

      if nearby_non_bananas.any?
        node = nearby_non_bananas.quick_min_by { shortest_path(chopper.node, _1).size }
        messages << "fullclear"
        go_and_chop(chopper, node)
        return
      end
    end

    # 1. clear seed node if it does not have a banana on it
    if cells[seed_node]&.tree && !cells[seed_node].tree.type?("BANANA")
      return go_and_chop(chopper, seed_node)
    end

    # 2. seed is open, chop bananas, then grown trees next to seed, finally anything
    grown_banana_nodes = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree && cells[_1].tree.grown? && cells[_1].tree.type?("BANANA") }
      # TODO, see if chopper can make it to my tree being felled by opp

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
      .select { cells[_1]&.tree && cells[_1].tree.turns_till_size(4) <= 2 }

    if growing.any?
      growest = growing.min_by { cells[_1].tree.turns_till_size(4) }

      if chopper.node == growest # already there!
        debug("== Chopper waiting on a growing tree")
      else # go if not there
        path = shortest_path(chopper.node, growest)
        plans[worker.id] = Plan.new("MOVE", worker.id, nil, path[chopper.move_speed] || path.last)
      end
      return
    end

    debug("== Hmmmm, no choppable nor growing trees, helper slacking off?")

    closest_grown_tree = trees
      .select { _1.grown? && _1.node != seed_node }
      .min_by { shortest_path(chopper.node, _1.node).size }

    if closest_grown_tree
      messages << "beeline"
      return go_and_chop(chopper, closest_grown_tree.node)
    end

    debug("== D'oh, no grown trees, checking any trees")

    closest_tree = trees.min_by { shortest_path(chopper.node, _1.node).size }
    if closest_tree
      messages << "slim pickings"
      return go_and_chop(chopper, closest_tree.node)
    end

    debug("== no trees on map, entering endgame")
    closest_dropoff = dropoff_nodes.min_by { shortest_path(chopper.node, _1).size }
    messages << "hugging base"
    go_and_chop(chopper, closest_dropoff)
  end

  # a generic going. Checks about having reached should occur beforehand in callers.
  def go(worker, node)
    path = shortest_path(worker.node, node)
    plans[worker.id] = Plan.new("MOVE", worker.id, nil, path[worker.move_speed] || path.last)
  end

  def go_and_mine(worker, node)
    if worker.node == node # already there!
      plans[worker.id] = Plan.new("MINE", worker.id) # "MINE #{worker.id}"
    else # go if not there
      messages << "IROON!"
      go(worker, node)
    end
  end

  def go_and_harvest(worker, node)
    if worker.node == node # already there!
      plans[worker.id] = Plan.new("HARVEST", worker.id)
    else # go if not there
      go(worker, node)
    end
  end

  def go_and_pick(worker, node, type)
    if worker.node == node # already there!
      plans[worker.id] = Plan.new("PICK", worker.id, type)
    else # go if not there
      go(worker, node)
    end
  end

  def go_and_plant(worker, node, type)
    if worker.node == node # already there!
      plans[worker.id] = Plan.new("PLANT", worker.id, type)
    else # go if not there
      go(worker, node)
    end
  end

  def go_and_chop(chopper, node)
    if chopper.node == node # already there!
      plans[worker.id] = Plan.new("CHOP", worker.id)
    else # go if not there
      go(chopper, node)
    end
  end

  def go_and_drop(worker, node)
    if dropoff_nodes.include?(worker.node) # already next to camp!
      plans[worker.id] = Plan.new("DROP", worker.id)
    else
      go(worker, node)
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

    @chopper ||= nil
    @inter ||= nil

    @workers = []
    lines.shift.to_i.times do
      id, player, x, y, move_speed, carry_capacity, harvest_power, chop_power, carry_plum, carry_lemon, carry_apple, carry_banana, carry_iron, carry_wood = lines.shift.split.map(&:to_i)

      worker = Worker.new(
        id, player, x, y,
        move_speed, carry_capacity, harvest_power, chop_power,
        carry_plum, carry_lemon, carry_apple, carry_banana, carry_iron, carry_wood
      )
      @workers << worker

      @cells["#{x} #{y}"] ||= Cell.new(x, y, nil, nil)
      @cells["#{x} #{y}"].worker = worker

      if worker.my?
        if worker.id == 0 || worker.id == 1
          @helper = worker
        elsif worker.chop_power > 2
          @chopper = worker
        else
          @inter = worker
        end
      end
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
        if %w[~ # +].include?(cell)
          grid.remove_cell(node)
        end

        grass_nodes << node if cell == "."
        water_nodes << node if cell == "~"
        iron_nodes << node if cell == "+"

        @my_camp = Camp.new(true, x, y) if cell == "0"
        @opp_camp = Camp.new(false, x, y) if cell == "1"
      end
    end

    grid.n4(my_camp.node).each do |next_to_camp|
      grid.remove_connection(next_to_camp, my_camp.node)
    end
    !opp_camp.nil? && grid.n4(opp_camp.node).each do |next_to_camp|
      grid.remove_connection(next_to_camp, opp_camp.node)
    end

    ms(">> wet/mining hybrid node init") do
      grass_nodes.each do |grass_node|
        wet_nodes << grass_node if @grid.n4(grass_node).any? { water_nodes.include?(_1) }
        mining_nodes << grass_node if @grid.n4(grass_node).any? { iron_nodes.include?(_1) }
      end
    end

    ms(">> dropoff points -> all grass init") do
      grid.neighbors(my_camp.node).each do |node|
        grass_nodes.each do |grass_node|
          shortest_path(node, grass_node)
        end
      end
    end
    #==

    ms("> tail-end of init") do
      ms(">> wet node init") { wet_nodes_within_3_of_camp }
      ms(">> seed note init") { seed_node }

      ms(">> grass -> seed node init") do
        grass_nodes.each do |grass_node|
          shortest_path(grass_node, seed_node)
        end
      end

      ms(">> w3 of camp except seed") { nodes_within_3_of_camp_except_seed }

      ms(">> dropoffs -> mining init") do
        mining_nodes.each do |mining_node|
          grid.neighbors(my_camp.node).each do |grass_node|
            shortest_path(grass_node, mining_node)
          end
        end
      end
    end

    nil
  end

  def shortest_path(from, to)
    key = [from, to]
    path = shortest_paths[key] || grid.shortest_path(*key)

    shortest_paths[key.reverse] ||= path.reverse
    shortest_paths[key] ||= path

    # also producing n-1 longth subpaths for ease of further navigation
    if (subpaths_exist = path.first(3).size == 3)
      key = [path[0], path[-2]]
      shortest_paths[key] ||= path[0..-2]
      shortest_paths[key.reverse] ||= path[0..-2].reverse

      key = [path[1], path[-1]]
      shortest_paths[key] ||= path[1..-1]
      shortest_paths[key.reverse] ||= path[1..-1].reverse
    end

    path
  rescue => e
    debug("XX Could not get path from #{from} to #{to}")
    raise
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

  def dropoff_nodes
    @dropoff_nodes ||= grid.neighbors(my_camp.node)
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

  def mining_nodes
    @mining_nodes ||= Set.new
  end

  # @return Array<Node>
  def shortest_path_to_mining
    shortest_path_to_mining ||= mining_nodes.flat_map do |mining_node|
      grid.neighbors(my_camp.node).map do |n|
        shortest_path(n, mining_node)
      end
    end.min_by { _1.size }
  end

  def iron_nodes
    @iron_nodes ||= Set.new
  end
end
