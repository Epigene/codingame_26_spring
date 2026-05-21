Camp = Struct.new(:my, :x, :y) do
  def node
    @node ||= "#{x} #{y}"
  end
end
Inventory = Struct.new(:plum, :lemon, :apple, :banana, :iron, :wood) do
  def has?(type)
    send(type.to_s.downcase).positive?
  end

  def can_afford?(cost_hash)
    cost_hash.all? { |type, count| send(type.downcase) >= count }
  end

  def score
    plum + lemon + apple + banana + (4 * wood)
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
    store = send(type.to_s.downcase)
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
Cell = Struct.new(:x, :y, :worker, :opp_worker, :tree)
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

  # A bit more flexible than #grown? because takes into account time to chop+growth
  def choppable_for_full_yield(chop_power)
    raise("#choppable_for_full_yield called for non-chopping worker, debug!") if chop_power.zero?

    return true if grown?

    copy = dup

    loop do
      copy.health -= chop_power
      return copy.size == 4 unless copy.health.positive?

      copy.apply_turn
    end
  end

  def grown?
    size == 4
  end

  # How many turns till tree will have at least 1 harvestable fruit
  def turns_till_fruit
    return 0 if fruit?

    (4 - size) * period + cooldown
  end

  # lower is better. Ideally 0 - if the worker is already there. Can be negative is several fruits
  #
  # @return Numeric
  def turns_till_fruit_in_hand(worker, path_to)
    distance_penalty = ((path_to.size - 1) / worker.move_speed.to_f).ceil
    return distance_penalty if fruits.positive?

    cooldown_penalty = (4 - size) * period + cooldown

    [distance_penalty, cooldown_penalty].max
  end

  def turns_till_chop(worker, path_to)
    move_turns = ((path_to.size - 1) / worker.move_speed.to_f).ceil
    chop_turns = chop_turns(worker.chop_power)

    move_turns + chop_turns
  end

  def fruits_at_arrival(turns)
    return 3 if fruits == 3

    turns_to_grow = grown? ? 0 : cooldown + (4 - (size + 1))*period

    return 0 if turns < turns_to_grow

    fruiting_turns = turns - turns_to_grow
    # at this point the tree will have just grown

    starting_cd = grown? ? cooldown : period
    cd_left = [starting_cd - fruiting_turns, 0].max
    return fruits if cd_left.positive?

    grown_fruits = 1
    fruiting_turns -= starting_cd
    # as this point the tree has just produced a fruit and cd is back to full period

    fruiting_periods = (fruiting_turns / period.to_f).floor

    [3, fruits + fruiting_periods + grown_fruits].min
  end

  # NOTE, distance to camp will never be lower than 1. 1 means tree is on a drop cell and no movement wil be needed
  #
  # @return Float
  def average_fruit_yield(distance_to_camp, worker)
    move_turns = ((distance_to_camp - 1) / worker.move_speed.to_f).ceil
    travel_turns = (move_turns * 2) + (_drop_turn = 1)
    min_cycle = travel_turns + (_one_harvest = 1)

    return 1/period.to_f if min_cycle < period

    # Fruit available when arriving again
    available_fruit = [
      _max_fruit = 3,
      (min_cycle / period.to_f),
    ].min

    carried_fruit = [available_fruit, worker.carry_capacity].min

    harvest_turns = (carried_fruit / worker.harvest_power.to_f)

    cycle_length = travel_turns + harvest_turns

    (carried_fruit / cycle_length.to_f).round(2)
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

  def carrying?(fruit_type, at_least_count = 1)
    send("carry_#{fruit_type.to_s.downcase}") >= at_least_count
  end

  def carry_seed?
    carrying?("PLUM") ||
      carrying?("LEMON") ||
      carrying?("APPLE") ||
      carrying?("BANANA")
  end

  # Expects #carry_seed? to have been called beforehand
  def carried_seed
    %w[PLUM LEMON APPLE BANANA].each do |type|
      return type if carrying?(type)
    end

    raise("#carried_seed called on a non-carrying worker")
  end

  # @return Integer
  def free_capacity
    carry_capacity - (
      carry_plum + carry_lemon + carry_apple + carry_banana + carry_iron + carry_wood
    )
  end

  def less_than_half_free?
    (free_capacity / carry_capacity.to_f) < 0.5
  end

  def can_chop?
    chop_power.positive?
  end

  def can_harvest?
    harvest_power.positive?
  end

  def mining_turns
    raise("chopless worker in minging logic, debug!") if chop_power.zero?

    (carry_capacity / chop_power.to_f).ceil
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

  def name?(desired_name)
    name == desired_name
  end

  def chop?
    name == "CHOP"
  end

  def weight
    @weight || 0
  end
end

Prediction = Struct.new(:move, :carry, :harvest, :chop, :costs, :turns, :remaining_turns) do
  def name
    "#{move} #{carry} #{harvest} #{chop}"
  end

  # key value, tells plan's worth.
  def grand_total
    chop_points - cost
  end

  def cost
    costs.except("IRON").values.sum
  end

  def wood_points_per_cycle
    4 * carry
  end

  def cycle_length
    (6 / chop) + 4
  end

  def chop_cycles
    (remaining_turns / cycle_length.to_f).floor
  end

  def chop_points
    chop_cycles * wood_points_per_cycle
  end

  def report
    debug(
      "== #{name} chopper would take ~#{turns} to train, costing #{cost}, " \
      "leaving #{remaining_turns} turns with a payout of #{wood_points_per_cycle} every #{cycle_length} turns," \
      "earning #{chop_points}-#{cost}=#{grand_total}"
    )
  end
end

class Controller
  attr_reader :field, :turn, :input, :grid,
    :my_camp, :opp_camp, :my_inventory, :opp_inventory,
    :cells, :trees,
    :workers, :helper, :inter, :chopper,
    :predictions, :best_prediction,
    :training, :messages, :plans,
    :distance_between_camps,
    :init_start, :t0

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
    ms("> Grid init") { init_grid }
  end

  def inspect
    "#<#{self.class} field=#{@field.inspect}>"
  end

  # @param turn Integer
  # @param input String # the raw as-is multiline input provided by game
  # @return String
  def call(turn:, input:)
    @t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @turn = turn
    debug(@input = input)
    init_turn_variables!
    @training = nil
    @messages = []
    @plans = {} # worker-id-keyed

    if turn <= 1
      # in how many turns is it OK to scale straight to chopper. Can probably go lower than 70, maybe 50.
      if turns_till_chopper > 65
        potential_worker = my_inventory.best_intermediate_worker(my_workers.size)
        if potential_worker
          @training = "TRAIN #{potential_worker}"
        end
      end
    end

    if chopper.nil? && my_inventory.can_afford?(best_prediction.costs)
      debug("= OK, time to get chopper #{best_prediction.name} and start chopping!")
      @training = "TRAIN #{best_prediction.name}"
    end

    if chopper
      ms("> chopper plan calc") do
        organize_chopping(chopper)
      end
    end

    ms("> helper plan calc") do
      organize_helper(helper) # helper is calculated before inter because inter will be able to work around helper
    end
    ms("> inter plan calc") do
      organize_intermediate(inter) if inter
    end

    result = [
      messages.any? ? "MSG #{messages.join(", ")}" : nil,
      training,
      *plans.values.sort_by { -_1.weight }.map(&:command)
    ].compact.join("; ")

    if turn_time_remaining > 5
      prefill_tree_paths
    end

    elapsed_ms = turn_time_taken
    debug("== turn #{turn} took #{elapsed_ms}ms to calculate")
    raise("Turn #{turn} took #{elapsed_ms}ms to calculate, too slow!") if elapsed_ms > 55

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

  # @return Prediction
  def predict(move, carry, harvest, chop)
    ms("== #{move} #{carry} #{harvest} #{chop} chopper") do
      costs = worker_cost(move, carry, harvest, chop)

      turns =
        turns_to_gather("PLUM", costs["PLUM"] - my_inventory.plum) +
        turns_to_gather("LEMON", costs["LEMON"] - my_inventory.lemon) +
        turns_to_gather("APPLE", costs["APPLE"] - my_inventory.apple) +
        turns_to_gather("IRON", costs["IRON"] - my_inventory.iron)

      remaining_turns = 300 - (turn + turns)

      p = Prediction.new(
        move, carry, harvest, chop, costs, turns, remaining_turns
      )
      p.report
      p
    end
  end

  # relies on @best_prediction having been set
  def aimed_chopper_cost
    best_prediction.costs
  end

  def organize_chopping(worker)
    # 0. unload if carrying wood for some reason
    if (trees.any?(&:grown?) ? worker.carry_wood.positive? : worker.full?) || (worker.full? && worker.carry_iron.positive?)
      return go_and_drop(worker, closest_dropoff(worker.node))
    end

    # WAR, seek to fight over chopping if opp within 2 turns can be cought
    chop_wars(worker)
    return if plans[worker.id]

    # 0, if outside base squares (beelined previously), continue on to nearest grown tree
    if !nodes_within_3_of_camp.include?(worker.node)
      closest_grown_tree = trees.select(&:grown?).min_by { shortest_path(worker.node, _1.node).size }
      if closest_grown_tree
        messages << "beeline"
        return go_and_chop(worker, closest_grown_tree.node)
      end
    end

    # 0, ENDGAME CLEAR
    if turn > 287
      nearby_bananas = nodes_within_3_of_camp
        .select { cells[_1]&.tree && cells[_1].tree.grown? && cells[_1].tree.type?("BANANA") }

      if nearby_bananas.any?
        node = nearby_bananas.quick_min_by { shortest_path(worker.node, _1).size }
        messages << "fullclear"
        go_and_chop(worker, node)
        return
      end

      nearby_non_bananas = nodes_within_3_of_camp
        .select { cells[_1]&.tree && cells[_1].tree.grown? && !cells[_1].tree.type?("BANANA") }

      if nearby_non_bananas.any?
        node = nearby_non_bananas.quick_min_by { shortest_path(worker.node, _1).size }
        messages << "fullclear"
        go_and_chop(worker, node)
        return
      end
    end

    # 1. clear seed node if it does not have a banana on it
    if cells[seed_node]&.tree && !cells[seed_node].tree.type?("BANANA")
      return go_and_chop(worker, seed_node)
    end

    # 2. seed is open, now chop bananas
    choppable = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree && cells[_1].tree.type?("BANANA") && cells[_1].tree.choppable_for_full_yield(worker.chop_power) }

    if choppable.any?
      closest = choppable.min_by { shortest_path(worker.node, _1).size }
      return go_and_chop(worker, closest)
    end

    grown_next_to_seed = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree && cells[_1].tree.grown? && grid.neighbors(seed_node).include?(_1) }

    if grown_next_to_seed.any?
      closest = grown_next_to_seed.min_by { shortest_path(worker.node, _1).size }
      return go_and_chop(worker, closest)
    end

    grown = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree && cells[_1].tree.grown? }

    if grown.any?
      closest = grown.min_by { shortest_path(worker.node, _1).size }
      return go_and_chop(worker, closest)
    end

    debug("= Hmm, no choppable trees, guess lets go to soonest choppable")

    growing = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree && cells[_1].tree.turns_till_size(4) <= 2 }

    if growing.any?
      growest = growing.min_by { cells[_1].tree.turns_till_size(4) }

      if worker.node == growest # already there!
        debug("= Chopper waiting on a growing tree")
        return
      else # go if not there
        return go(worker, growest)
      end
    end

    debug("= Hmmmm, no choppable nor growing trees, helper slacking off?")

    closest_grown_tree = trees
      .select { _1.grown? && _1.node != seed_node }
      .min_by { shortest_path(worker.node, _1.node).size }

    if closest_grown_tree
      messages << "beeline"
      return go_and_chop(worker, closest_grown_tree.node)
    end

    debug("= D'oh, no grown trees, checking any trees")

    closest_tree = trees.min_by { shortest_path(worker.node, _1.node).size }
    if closest_tree
      messages << "slim pickings"
      return go_and_chop(worker, closest_tree.node)
    end

    debug("= no trees on map, entering endgame")
    messages << "hugging opp"
    go_and_chop(worker, opp_dropoff_nodes.min_by { shortest_path(worker.node, _1).size })
  end

  def organize_helper(worker)
    # 0. unload if carrying wood for some reason
    if worker.carry_wood.positive? || (worker.full? && worker.carry_iron.positive?)
      return go_and_drop(worker, closest_dropoff(worker.node))
    end

    # WAR, seek to fight over chopping if opp within 2 turns can be cought
    chop_wars(worker)
    return if plans[worker.id]

    # ENDGAME, I'm winning, let's liquidate
    if my_inventory.score > opp_inventory.score + 40 && trees.size < 6
      tree = trees.min_by { shortest_path(worker.node, _1.node) }
      messages << "endgame"
      seek_to_chop(worker, tree.node) if tree
    end
    return if plans[worker.id]

    # 65 turns are known to be too many, 50 likely ok, but may go lower
    if no_way_to_scale_to_chopper
      debug("= Helper sees no time to scale to chopper, self-planting")

      # dropping carried wood is handled

      seek_to_self_plant(worker)
      return if plans[worker.id]

      # hmm, no seeds left, time to chop anything
      tree = trees.min_by { shortest_path(worker.node, _1.node).size }
      return go_and_chop(worker, tree.node) if tree
    end

    # Initial boosting has one goal - be able to afford an excellent chopper worker.
    # It consists of 3 subgoals:
    #  1. Reach 17 lemons
    #  2. 10 iron
    #  3. 5 plums (easy)
    if chopper.nil? && !training.to_s.match?(%r'TRAIN \d+ \d+ 0')
      debug("= Helper will help scale to chopper")

      seek_to_plant_carried_banana(worker) ||
        (my_inventory.lemon < aimed_chopper_cost["LEMON"] && ensure_sufficient_lemon_growth(worker)) ||
        (my_inventory.plum < aimed_chopper_cost["PLUM"] && ensure_sufficient_plum_growth(worker)) ||
        harvest_already_stood_on_tree(
          worker,
          *[(my_inventory.lemon < aimed_chopper_cost["LEMON"] ? "LEMON" : nil), (my_inventory.plum < aimed_chopper_cost["PLUM"] ? "PLUM" : nil)].compact
        ) ||
        (my_inventory.lemon < aimed_chopper_cost["LEMON"] && gather_initial_fruit(worker, "LEMON", 5)) ||
        (my_inventory.plum < aimed_chopper_cost["PLUM"] && gather_initial_fruit(worker, "PLUM", 5)) ||
        (my_inventory.iron < aimed_chopper_cost["IRON"] && inter.nil? && gather_iron(worker)) ||
        (
          my_inventory.lemon >= aimed_chopper_cost["LEMON"] && my_inventory.plum >= aimed_chopper_cost["PLUM"] &&
            gather_iron(worker)
        ) ||
        (inter && (turns_till_chopper < 15) && seek_to_plant_banana(worker)) ||
        (my_inventory.lemon < aimed_chopper_cost["LEMON"] && gather_initial_fruit(worker, "LEMON", 10)) ||
        (my_inventory.plum < aimed_chopper_cost["PLUM"] && gather_initial_fruit(worker, "PLUM", 10)) ||
        (my_inventory.apple < aimed_chopper_cost["APPLE"] && gather_anywhere_fruit(worker, "APPLE", 30)) ||
        (my_inventory.iron < aimed_chopper_cost["IRON"] && gather_iron(worker)) # TODO, may need to detect inter already grabbing last piece

      debug("= not clear how helper could help scale to chopper!") if plans[worker.id].nil?

      harvest_closest_harvestable(worker) unless plans[worker.id]
    end
    return if plans[worker.id]

    # == Regular helping starts ==

    # detect self-seeding phase
    if trees.select(&:grown?).none?
      seek_to_self_plant(worker)
      return if plans[worker.id]
    end

    if worker.full? && worker.carry_banana.zero?
      return go_and_drop(worker, closest_dropoff(worker.node))
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

    seek_to_plant_banana(worker)
  end

  def organize_intermediate(worker)
    # 0. unload if carrying wood for some reason
    if worker.carry_wood.positive? || (worker.full? && worker.carry_iron.positive?)
      return go_and_drop(worker, closest_dropoff(worker.node))
    end

    xms("> inter chop wars") do
      chop_wars(worker) if chopper.nil?
      return if plans[worker.id]
    end

    # ENDGAME, I'm winning, let's liquidate
    xms("> inter endgame") do
      if my_inventory.score > opp_inventory.score + 40 && trees.size < 6
        tree = trees.min_by { shortest_path(worker.node, _1.node) }
        seek_to_chop(worker, tree.node) if tree
      end
      return if plans[worker.id]
    end

    if no_way_to_scale_to_chopper
      debug("== inter sees #{turns_till_own_lemon_tree} turns till lemon as too far for scaling")

      messages << "race to bottom"

      # don't get in the way of helper's self-seed harvesting
      helper_chop = cells[helper.node]&.tree&.node

      bananatree = trees.select { _1.type?("BANANA") && _1.node != helper_chop }
        .min_by { _1.turns_till_chop(worker, shortest_path(worker.node, _1.node)) }

      if bananatree
        return seek_to_chop(worker, bananatree.node)
      end

      plumtree = trees.select { _1.type?("PLUM") && _1.node != helper_chop }
        .min_by { _1.turns_till_chop(worker, shortest_path(worker.node, _1.node)) }
      if plumtree
        return seek_to_chop(worker, plumtree.node)
      end

      lemontree = trees.select { _1.type?("LEMON") && _1.node != helper_chop }
        .min_by { _1.turns_till_chop(worker, shortest_path(worker.node, _1.node)) }
      if lemontree
        return seek_to_chop(worker, lemontree.node)
      end

      appletree = trees.select { _1.type?("APPLE") && _1.node != helper_chop }
        .min_by { _1.turns_till_chop(worker, shortest_path(worker.node, _1.node)) }
      if appletree
        return seek_to_chop(worker, appletree.node)
      end
    end

    xms("> inter chopper scaling") do
      if chopper.nil? && !training.to_s.match?(%r'TRAIN \d+ \d+ 0')
        debug("== inter helping scale to chopper")

        (my_inventory.lemon.zero? && trees_within_3_of_camp.none? { _1.type?("LEMON") } && gather_and_plant(worker, "LEMON")) ||
          (my_inventory.plum.zero? && trees_within_3_of_camp.none? { _1.type?("PLUM") } && gather_and_plant(worker, "PLUM")) ||
          (my_inventory.lemon < 2 && gather_initial_fruit(worker, "LEMON", 1)) ||
          (my_inventory.plum < 2 && gather_initial_fruit(worker, "PLUM", 1)) ||
          (my_inventory.lemon < 2 && gather_initial_fruit(worker, "LEMON", 2)) ||
          (my_inventory.plum < 2 && gather_initial_fruit(worker, "PLUM", 2)) ||
          (my_inventory.lemon < 6 && gather_initial_fruit(worker, "LEMON", 1)) ||
          (my_inventory.plum < 6 && gather_initial_fruit(worker, "PLUM", 1)) ||
          (my_inventory.lemon < 6 && gather_initial_fruit(worker, "LEMON", 2)) ||
          (my_inventory.plum < 6 && gather_initial_fruit(worker, "PLUM", 2)) ||
          (my_inventory.lemon < aimed_chopper_cost["LEMON"] && gather_initial_fruit(worker, "LEMON", 1)) ||
          (my_inventory.plum < aimed_chopper_cost["PLUM"] && gather_initial_fruit(worker, "PLUM", 1)) ||
          (my_inventory.lemon < aimed_chopper_cost["LEMON"] && gather_anywhere_fruit(worker, "LEMON", 2)) ||
          (my_inventory.plum < aimed_chopper_cost["PLUM"] && gather_anywhere_fruit(worker, "PLUM", 2)) ||
          (my_inventory.apple < aimed_chopper_cost["APPLE"] && gather_anywhere_fruit(worker, "APPLE", 30)) ||
          (my_inventory.iron < aimed_chopper_cost["IRON"] && gather_iron(worker)) ||
          debug("= Huh? inter has nothing to do for scaling to chopper!")
          # (my_inventory.plum < aimed_chopper_cost["PLUM"] && gather_initial_fruit(worker, "PLUM", 20)) ||
          # (my_inventory.lemon < aimed_chopper_cost["LEMON"] && gather_initial_fruit(worker, "LEMON", 20))

        # binding.pry
      end
      return if plans[worker.id]
    end

    xms("> inter dropoff calc") do
      if worker.full?
        return go_and_drop(worker, closest_dropoff(worker.node))
      end
    end

    # regular harvesting
    xms("> regular inter harvesting") do
      harvest_closest_harvestable(worker)
      return if plans[worker.id]
    end

    if trees.select(&:grown?).none?
      seek_to_self_plant(worker)
      return if plans[worker.id]
    end

    debug("= hmm, inter has nothing to do")
  end

  # Regular harvesting for inter
  def harvest_closest_harvestable(worker)
    closest_harvestable_tree = trees.select do |tree|
      # let's never try to harvest what chopper is cutting down
      next false if plans[chopper&.id]&.chop? && plans[chopper.id].node == tree.node
      next false if tree.node == seed_node

      tree.size > 1
    end
    .sort_by { grid.manhattan_distance(worker.node, _1.node) }.first(10)
    .select do |tree|
      turns_to_reach = ((shortest_path(worker.node, tree.node).size - 1) / worker.move_speed.to_f).ceil

      tree.fruits_at_arrival(_turns = turns_to_reach) >= worker.free_capacity
    end
    .sort_by do |tree|
      [shortest_path(worker.node, tree.node).size, tree.period]
    end.first

    if closest_harvestable_tree
      return go_and_harvest(worker, closest_harvestable_tree.node)
    end

    false
  end

  # used by helper and inter
  def seek_to_chop(worker, node)
    if worker.full?
      return go_and_drop(worker, closest_dropoff(worker.node))
    else
      go_and_chop(worker, node)
    end
  end

  # seek to plant in a cell on my side
  def seek_to_self_plant(worker)
    # TODO, this could be improved to actual opp worker speed checks
    return if workers.any? { !_1.my? && nodes_within_3_of_camp.include?(_1.node) }

    if worker.carry_seed?
      closest_my_node = my_nodes.select { cells[_1]&.tree.nil? }
        .sort_by { [shortest_path(my_camp.node, _1).size, shortest_path(worker.node, _1)] }.first

      return go_and_plant(worker, closest_my_node, worker.carried_seed)
    end

    if cells[worker.node]&.tree
      return go_and_chop(worker, worker.node)
    end

    # go grab a seed
    seed = self_harvest_seed
    if seed
      my_side_candidates = (my_nodes & dropoff_nodes) - plans.values.map(&:node)

      self_seeding_node =
        if my_side_candidates.any?
          my_side_candidates.min_by { shortest_path(worker.node, _1).size }
        else
          dropoff_nodes.min_by { shortest_path(worker.node, _1).size }
        end

      return go_and_pick(worker, self_seeding_node, seed)
    end
  end

  def seek_to_plant_carried_banana(worker)
    return unless worker.carry_banana.positive?

    # 1. seek to plant a banana on seed node
    if cells[seed_node]&.tree.nil?
      return go_and_plant(worker, seed_node, "BANANA")
    end

    # 2. seek to plant next to seed node
    closest = nodes_within_3_of_camp_except_seed
      .select { cells[_1]&.tree.nil? }
      .min_by do |node|
        shortest_path(worker.node, node).size + shortest_path(my_camp.node, node).size +
          shortest_path(seed_node, node).size -
          # wetness is treated as being half a square closer, giving a tiebreaking advantage
          (wet_nodes.include?(node) ? 0.5 : 0)
      end

    if closest
      return go_and_plant(worker, closest, "BANANA")
    end

    false
  end

  def seek_to_plant_banana(worker)
    seek_to_plant_carried_banana(worker)
    return if plans[worker.id]

    # not carrying a banana, should get one
    seeding_bananas =
      cells[seed_node]&.tree&.type?("BANANA") &&
      cells[seed_node]&.tree&.turns_till_fruit_in_hand(worker, shortest_path(worker.node, seed_node)) < 5

    if (tree = cells[worker.node]&.tree) && tree.type?("BANANA") && tree.fruit? # ON banana
      go_and_harvest(worker, tree.node)
    elsif seeding_bananas
      return go_and_harvest(worker, seed_node)
    elsif my_inventory.banana.positive?
      return go_and_pick(worker, closest_dropoff(worker.node), "BANANA")
    elsif (banana_nodes = cells.select { |node, cell| cell&.tree&.type?("BANANA") }).any?
      closest, _cell = banana_nodes.min_by do |node, cell|
        cell.tree.turns_till_fruit_in_hand(worker, shortest_path(worker.node, node))
      end

      if closest
        return go_and_harvest(worker, closest)
      end
    else
      debug("= Hmm, no banana trees on map?")
    end
  end

  def harvest_already_stood_on_tree(worker, *types)
    return if worker.full?

    tree = cells[worker.node]&.tree
    return unless tree
    return unless types.include?(tree.type)
    return unless tree.fruit?

    messages << "oh #{tree.type}"
    go_and_harvest(worker, tree.node)
  end

  def ensure_sufficient_lemon_growth(worker)
    expected_lemon_production_near_camp_per_turn = nodes_within_3_of_camp.sum do |near_node|
      cell = cells[near_node]
      next 0 if cell.nil? || cell.tree.nil? || cell.tree.type != "LEMON"

      wet_nodes.include?(near_node) ? (1/3.0) : (1/8.0)
    end
    debug "= Eventual Lemon production near camp per turn #{expected_lemon_production_near_camp_per_turn}"

    return if expected_lemon_production_near_camp_per_turn >= (2/8.0) # one watered or 2 regular

    wet_path = wet_nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
      .map { shortest_path(my_camp.node, _1) }
      .min_by { _1.size }

    if wet_path
      return handle_planting_at_end_of(worker, wet_path, "LEMON")
    end

    regular_path, _ = nodes_within_3_of_camp.select { cells[_1].nil? || cells[_1].tree.nil? }
      .map { [shortest_path(my_camp.node, _1), shortest_path(worker.node, _1), shortest_path(opp_camp.node, _1)] }
      .min_by { _1.size + _2.size - _3.size }

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
    debug "= Eventual Plum production near camp per turn #{expected_plum_production_near_camp_per_turn}"

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
    if worker.node == path.last && worker.carrying?(tree_type)
      return plans[worker.id] = Plan.new("PLANT", worker.id, tree_type)
    elsif worker.carrying?(tree_type)
      return go(worker, path.last)
    elsif worker.node == path[1] && !worker.carrying?(tree_type) && my_inventory.has?(tree_type)
      return plans[worker.id] = Plan.new("PICK", worker.id, tree_type)
    elsif my_inventory.has?(tree_type) # as in no lemon in hand, go to near camp
      return go(worker, path[1])
    end

    false
  end

  def gather_iron(worker)
    if worker.full?
      return go_and_drop(worker, closest_dropoff(worker.node))
    end

    closest_mine = mining_nodes.min_by { shortest_path(worker.node, _1).size }
    return go_and_mine(worker, closest_mine)
  end

  # a generic going. Checks about having reached should occur beforehand in callers.
  def go(worker, node)
    excludable =
      if worker.id == chopper&.id
        nil
      else
        plans[chopper&.id]&.node
      end

    path =
      shortest_path(worker.node, node, excluding: excludable ? [excludable] : nil) ||
      shortest_path(worker.node, node)

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

  def go_and_chop(worker, node)
    if worker.node == node # already there!
      plans[worker.id] = Plan.new("CHOP", worker.id, nil, node)
    else # go if not there
      go(worker, node)
    end
  end

  def go_and_drop(worker, node)
    if dropoff_nodes.include?(worker.node) # already next to camp!
      plans[worker.id] = Plan.new("DROP", worker.id)
    else
      go(worker, node)
    end
  end

  def gather_and_plant(worker, fruit_type)
    if worker.carrying?(fruit_type)
      node = nodes_within_3_of_camp_except_seed.select { cells[_1]&.tree.nil? }
        .min_by do |node|
          shortest_path(worker.node, node).size + shortest_path(my_camp.node, node).size -
            (wet_nodes.include?(node) ? 0.5 : 0)
        end

      raise("oof, no free cells near base") if node.nil?

      return go_and_plant(worker, node, fruit_type)
    else
      closest_fruit = trees.select { _1.type?(fruit_type) }
        .min_by { _1.turns_till_fruit_in_hand(worker, shortest_path(worker.node, _1.node)) }

      unless closest_fruit
        debug("= Wow, I have no #{fruit_type} at camp and no trees on map")
        return false
      end

      messages << "getting seed #{fruit_type}"
      return go_and_harvest(worker, closest_fruit.node)
    end

    false
  end

  # Used by both helper and inter, helper gets prio
  # Contrast with #gather_anywhere_fruit
  def gather_initial_fruit(worker, fruit_type, max_wait)
    if worker.full?
      return go_and_drop(worker, closest_dropoff(worker.node))
    end

    if cells[worker.node]&.tree&.type == fruit_type && cells[worker.node]&.tree&.fruit? # at a tree already!
      plans[worker.id] = Plan.new("HARVEST", worker.id)
    else # gotta detect and go to a good candidate tree
      # binding.pry if fruit_type == "LEMON"
      path_to_tree, turns_till = nodes_within_3_of_camp
        .select do |node|
          next false unless (tree = cells[node]&.tree&.type?(fruit_type))

          # seeking to disqualify trees worked on by helper
          plan = plans[helper.id]
          next true unless plan

          next false if plan.name?("HARVEST") && helper.node == node
          next false if plan.name?("MOVE") && plan.node == node

          true
        end
        .map do |node|
          path = shortest_path(worker.node, node)
          [path, cells[node].tree.turns_till_fruit_in_hand(worker, path)]
        end.select { _2 <= max_wait }.min_by { |_path, turns_till| turns_till }

      if path_to_tree.nil?
        debug("= No #{fruit_type} trees qualify for early harvesting with a wait time of #{max_wait}")
        return
      end

      messages << "trns till #{fruit_type} #{turns_till}"
      go(worker, path_to_tree.last)
    end
  end

  # Reserved for dire straits like last apples for chopper
  def gather_anywhere_fruit(worker, fruit_type, max_wait)
    if worker.full?
      return go_and_drop(worker, closest_dropoff(worker.node))
    end

    if cells[worker.node]&.tree&.type == fruit_type && cells[worker.node]&.tree&.fruit? # at a tree already!
      return plans[worker.id] = Plan.new("HARVEST", worker.id)
    end

    tree_path, turns_till = trees
      .select { _1.type?(fruit_type) && !(plans[helper.id]&.name?("HARVEST") && helper.node == _1.node) }
      .map do |tree|
        path = shortest_path(worker.node, tree.node)
        [path, tree.turns_till_fruit_in_hand(worker, path)]
      end
      .select { _2 <= max_wait }.min_by { |_path, turns_till| turns_till }

    if tree_path.nil?
      debug("= No #{fruit_type} trees qualify any-dist harvesting with wait of #{max_wait}")
      return
    end

    messages << "trns till #{fruit_type} #{turns_till}"
    go(worker, tree_path.last)
  end

  # assumes free-ish hands
  def chop_wars(worker)
    xms(">> CHOP WARS calc for worker #{worker}") do
      return if !worker.can_chop?
      # WAR, seek to fight over chopping if opp within 2 turns can be cought
      opp_workers_chopping = workers.select { !_1.my? }.select { _1.can_chop? && cells[_1.node]&.tree&.damaged? }
      return if opp_workers_chopping.none?

      # maybe already ON chop node
      worker_tree = cells[worker.node]&.tree
      if worker_tree && cells[worker.node]&.opp_worker && worker_tree.damaged?
        # hey, maybe we're next to base and we can wait efficiently with harvesting in the meantime
        if dropoff_nodes.include?(worker_tree.node)
          opp_worker = cells[worker.node].opp_worker
          turns_to_fell = worker_tree.chop_turns(opp_worker.chop_power)

          # in three turns we can do PICK, DROP and then final CHOP
          if turns_to_fell >= 3 && worker_tree.fruit?
            return go_and_harvest(worker, worker_tree.node)
          end
        else # can't harvest in meantime, Need to chop or wait
          opp_worker = cells[worker.node]&.opp_worker

          if worker.chop_power > opp_worker.chop_power
            # we have the better chop, so might as well put and end to this war
            go_and_chop(worker, worker.node)
          else
            messages << "#{worker.id} waiting"
            go(worker, worker.node) # as in stay put without doing anything
          end
        end
      end

      chops = opp_workers_chopping.map do |opp_worker|
        tree = cells[opp_worker.node].tree
        path = shortest_path(worker.node, opp_worker.node)
        turns_to_reach =
          ((path.size - 1) / worker.move_speed.to_f).ceil +
          (turns_to_drop(worker) * 2) # doubling to account for possible going opposite way. Usually will be 0 anyway

        turns_to_fell = tree.chop_turns(opp_worker.chop_power)
        [path, turns_to_reach, turns_to_fell]
      end

      interceptable_chops =
        if trees.size > 2
          chops.select { |p, to_reach, to_fell| to_fell < 5 && to_reach <= 3 && (to_reach + 1) <= to_fell }
        else # as in last 2 trees
          chops.select { |p, to_reach, to_fell| to_fell < 6 && to_reach <= 5 && (to_reach + 1) <= to_fell }
        end

      if interceptable_chops.any?
        path, _, _ = interceptable_chops.quick_max_by { |p, to_reach, to_fell| cells[p.last].tree.size }

        if worker.full?
          messages << "*cracks neck*"
          return go_and_drop(worker, shortest_path_to_drop(worker.node))
        end

        messages << "chop warz"
        return go_and_chop(worker, path.last)
      end
    end
  end

  # Major predictive logic
  def turns_to_gather(type, count)
    return 0 unless count.positive?

    if type == "IRON"
      xms(">>> #turns_to_gather #{type} #{count}") do
        yields = []

        # start with quickest worker
        my_workers.select(&:can_chop?)
          .sort_by { [-_1.move_speed, -_1.carry_capacity, -_1.chop_power] }
          .each_with_index do |worker, i|
            mining_cycle =
              ((shortest_path_to_mining.size - 1) / worker.move_speed.to_f).ceil * 2 +
              (_drop = 1) +
              (_mining_turns = worker.mining_turns)

            yields << (worker.carry_capacity / mining_cycle.to_f) * (0.8**i)
          end

        return 300 if yields.sum.zero?
        (count / yields.sum.to_f).ceil
      end
    else # for fruits
      xms(">>> #turns_to_gather #{type} #{count}") do
        penalty_turns = nil
        yields = []

        harvesters = xms(">>>> harvester lookup") do
          my_workers.select(&:can_harvest?).sort_by { [-_1.move_speed, -_1.carry_capacity, -_1.chop_power] }
        end

        harvesters.each_with_index do |worker, i|
          best_tree, average_yield = xms(">>>> best_tree, average_yield lookup") do
            trees.select { _1.type?(type) }.map do |tree|
              camp_to_tree_path = shortest_path(my_camp.node, tree.node)
              distance_to_camp = camp_to_tree_path.size - 1
              [tree, tree.average_fruit_yield(distance_to_camp, worker)]
            end
            .sort_by { |t, average_yield| -average_yield }[i..-1]&.first
          end

          if best_tree
            yields << average_yield.to_f / (0.8**i)
          else # no tree, maybe we can plant
            next unless my_inventory.has?(type) # since no way to get more fruit

            penalty_turns ||= 15

            if wet_nodes_within_3_of_camp.any?
              yields << (1/5.0) / (0.8**i)
            else
              yields << (1/9.0) / (0.8**i)
            end
          end
        end

        return 300 if yields.sum.zero?
        (count / yields.sum.to_f).ceil + penalty_turns.to_i
      end
    end
  end

  def turns_to_drop(worker)
    return 0 unless worker.full?

    ((shortest_path_to_drop(worker.node).size - 1) / worker.move_speed.to_f).ceil + 1
  end

  # @return Node
  def closest_dropoff(from_node)
    dropoff_nodes.min_by { shortest_path(from_node, _1).size }
  end

  # @return Array<Node>
  def shortest_path_to_drop(from_node)
    shortest_path(from_node, closest_dropoff(from_node))
  end

  # @return Hash {move: 1, ..}
  def worker_cost(move, carry, harvest, chop)
    existing_workers = my_workers.size

    {
      "PLUM" => existing_workers + (move**2),
      "LEMON" => existing_workers + (carry**2),
      "APPLE" => existing_workers + (harvest**2),
      "IRON" => existing_workers + (chop**2)
    }
  end

  # @return String, nil
  def self_harvest_seed
    # %w[BANANA PLUM LEMON APPLE].each do |type|
    # apples not worth it
    %w[BANANA PLUM LEMON].each do |type|
      return type if my_inventory.has?(type)
    end

    nil
  end

  # 65 turns are known to be too many, 50 likely ok, but may go lower
  def no_way_to_scale_to_chopper
    chopper.nil? && my_inventory.lemon < 4 && (turns_till_own_lemon_tree + turn) > 50
  end

  def turns_till_chopper
    -[my_inventory.plum - 5, 0].min * 5 +
      -[my_inventory.lemon - 17, 0].min * 5 +
      -[my_inventory.apple - 1, 0].min * 5 +
      -[my_inventory.iron - 10, 0].min * shortest_path_to_mining.size * 2
  end

  # Not just tree, but 1st fruit from it
  def turns_till_own_lemon_tree
    @turns_till_own_lemon_tree ||= {}
    return @turns_till_own_lemon_tree[turn] if @turns_till_own_lemon_tree.key?(turn)

    nearby_lemon = trees_within_3_of_camp.select { _1.type?("LEMON") }
      .min_by { _1.turns_till_fruit_in_hand(helper, shortest_path(helper.node, _1.node)) }

    if nearby_lemon
      return @turns_till_own_lemon_tree[turn] =
        nearby_lemon.turns_till_fruit_in_hand(helper, shortest_path(helper.node, nearby_lemon.node))
    end

    # ok, maybe I can plant
    if my_inventory.lemon.positive?
      if wet_nodes_within_3_of_camp.any?
        example_node = wet_nodes_within_3_of_camp.first
        cd_and_period = tree_period_mapping.dig(:wet, "LEMON")
        return @turns_till_own_lemon_tree[turn] = Tree.new("LEMON", example_node.x, example_node.y, 1, 8, 0, cd_and_period, cd_and_period)
          .turns_till_fruit_in_hand(helper, shortest_path(helper.node, example_node))
        # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      else
        example_node = dropoff_nodes.first
        cd_and_period = tree_period_mapping.dig(:dry, "LEMON")
        return @turns_till_own_lemon_tree[turn] = Tree.new("LEMON", example_node.x, example_node.y, 1, 8, 0, cd_and_period, cd_and_period)
          .turns_till_fruit_in_hand(helper, shortest_path(helper.node, example_node))
        # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      end
    end

    # uff, no nearby trees and can't plant due to missing seeds. Only option is to
    # get a seed from further trees, get back, and plant it.
    possibilities = trees.select { _1.type?("LEMON") }
      .map do |tree|
        [
          tree,
          tree.turns_till_fruit_in_hand(helper, shortest_path(helper.node, tree.node)),
          _get_back_turns = shortest_path(tree.node, my_camp.node).size - 2,
          _new_growth =
            if wet_nodes_within_3_of_camp.any?
              example_node = wet_nodes_within_3_of_camp.first
              cd_and_period = tree_period_mapping.dig(:wet, "LEMON")
              Tree.new("LEMON", example_node.x, example_node.y, 1, 8, 0, cd_and_period, cd_and_period)
                .turns_till_fruit_in_hand(helper, shortest_path(helper.node, example_node))
              # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
            else
              example_node = dropoff_nodes.first
              cd_and_period = tree_period_mapping.dig(:dry, "LEMON")
              Tree.new("LEMON", example_node.x, example_node.y, 1, 8, 0, cd_and_period, cd_and_period)
                .turns_till_fruit_in_hand(helper, shortest_path(helper.node, example_node))
              # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
            end
        ]
      end

    best = possibilities.map do |tree, turns_till_fruit, get_back_turns, new_growth|
      turns_till_fruit + get_back_turns + new_growth
    end.min

    return @turns_till_own_lemon_tree[turn] = best if best

    return @turns_till_own_lemon_tree[turn] = 300
  end

  def my_workers
    @my_workers ||= {}
    return @my_workers[turn] if @my_workers.key?(turn)
    @my_workers[turn] = workers.select(&:my?)
  end

  def trees_within_3_of_camp
    @trees_within_3_of_camp ||= {}
    return @trees_within_3_of_camp[turn] if @trees_within_3_of_camp.key?(turn)
    @trees_within_3_of_camp[turn] = trees.select { nodes_within_3_of_camp.include?(_1.node) }
  end

  #===================
  #  TURN INIT BELOW
  #===================

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
      @cells["#{x} #{y}"] ||= Cell.new(x, y)
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

      @cells["#{x} #{y}"] ||= Cell.new(x, y)

      if worker.my?
        @cells["#{x} #{y}"].worker = worker

        if worker.id == 0 || worker.id == 1
          @helper = worker
        elsif worker.harvest_power.zero? && worker.carry_capacity >= 2 && worker.move_speed >= 2 && worker.chop_power >= 2
          @chopper = worker
        else
          @inter = worker
        end
      else
         @cells["#{x} #{y}"].opp_worker = worker
      end
    end

    init_predictions
  end

  # Predictions for which chopper to aim for.
  def init_predictions
    @predictions = []

    if chopper.nil?
      variants = [
        [2, 4, 0, 3], # best
        [2, 4, 0, 2], # -1chop
        [2, 3, 0, 3], # (-1carry)
        [2, 3, 0, 2], # (-1carry,-1chop)
      ]

      variants.each do |variant|
        p = predict(*variant)
        @predictions << p

        # no need to calc all four variants if the cheapest will take 100 turns
        # break if p.turns > 100
      end
    end

    @best_prediction = @predictions.sort_by { [-_1.grand_total, _1.turns] }.first

    nil
  end

  # a sort of postprocessing that uses time left at the end of a turn to precrunch shortest paths regarding trees
  def prefill_tree_paths
    trees.each do |tree|
      break if turn_time_remaining < 1

      shortest_path(my_camp.node, tree.node)
    end
  end

  # Grid init is a simple fill, bet we make caps leave-only (and maybe rocks in future leagues)
  def init_grid
    @init_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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

    # == camp distances and areas
    @distance_between_camps = [grid.shortest_path(my_camp.node, opp_camp.node).size - 2, 0].max

    grid.n4(my_camp.node).each do |next_to_camp|
      grid.remove_connection(next_to_camp, my_camp.node)
    end
    !opp_camp.nil? && grid.n4(opp_camp.node).each do |next_to_camp|
      grid.remove_connection(next_to_camp, opp_camp.node)
    end
    # ==

    ms(">> wet/mining hybrid node init") do
      grass_nodes.each do |grass_node|
        wet_nodes << grass_node if @grid.n4(grass_node).any? { water_nodes.include?(_1) }
        mining_nodes << grass_node if @grid.n4(grass_node).any? { iron_nodes.include?(_1) }
      end
    end

    ms(">> #my_nodes init") do
      grass_nodes.each do |grass_node|
        my_path = shortest_path(my_camp.node, grass_node).size - 1
        opp_path = shortest_path(opp_camp.node, grass_node).size - 1

        if my_path < opp_path && opp_path > distance_between_camps
          my_nodes << grass_node
        end
      end
    end

    return if init_time_remaining < 50

    #===
    return if defined?(LOCAL)
    #===

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

    ms(">> all near-camp node connections") do
      nodes_within_3_of_camp.each do |node|
        nodes_within_3_of_camp.each do |other_node|
          next if node == other_node

          shortest_path(node, other_node)
        end
      end
    end

    ms(">> wet node init") { wet_nodes_within_3_of_camp }
    ms(">> seed note init") { seed_node }

    ms(">> dropoff points -> all grass init") do
      grid.neighbors(my_camp.node).each do |node|
        break if init_time_remaining < 10

        grass_nodes.each do |grass_node|
          shortest_path(node, grass_node)
        end
      end
    end

    nil
  end

  # @return [Array<Node>, nil]
  def shortest_path(from, to, excluding: nil)
    raise(":from is nil, debug!") unless from.respond_to?(:x)
    raise(":to is nil, debug!") unless to.respond_to?(:y)

    key = [from, to, excluding]

    path =
      if shortest_paths.key?(key)
        shortest_paths[key]
      else
        shortest_paths[key] = grid.shortest_path(from, to, excluding: excluding)
      end

    r_key = [to, from, excluding]
    shortest_paths[r_key] ||=
      if path
        path.reverse
      else
        nil
      end
    return if shortest_paths[r_key].nil?

    # also producing n-1 longth subpaths for ease of further navigation
    if excluding.nil? && (subpaths_exist = path.first(3).size == 3)
      key = [path[0], path[-2], nil]
      shortest_paths[key] ||= path[0..-2]
      shortest_paths[key.reverse] ||= path[0..-2].reverse

      key = [path[1], path[-1], nil]
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
    return @seed_node if defined?(@seed_node)

    @seed_node =
      if wet_nodes_within_3_of_camp.any?
        wet_nodes_within_3_of_camp.sort_by do |node|
          [
            -(grid.neighbors(node) & nodes_within_3_of_camp).size,
            shortest_path(my_camp.node, node).size,
            -shortest_path(opp_camp.node, node).size
          ]
        end.first
      else
        nodes_within_3_of_camp.sort_by do |node|
          [
            -(grid.neighbors(node) & nodes_within_3_of_camp).size,
            shortest_path(my_camp.node, node).size,
            -shortest_path(opp_camp.node, node).size
          ]
        end.first
      end

    debug("= Seed node is #{@seed_node}")

    @seed_node
  end

  def dropoff_nodes
    @dropoff_nodes ||= grid.neighbors(my_camp.node)
  end

  def opp_dropoff_nodes
    opp_dropoff_nodes ||= grid.neighbors(opp_camp.node)
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
    @shortest_path_to_mining ||= mining_nodes.flat_map do |mining_node|
      grid.neighbors(my_camp.node).map do |n|
        shortest_path(n, mining_node)
      end
    end.min_by { _1.size }
  end

  def iron_nodes
    @iron_nodes ||= Set.new
  end

  # Taken to mean nodes not only closer to my camp but also "behind" my camp from opp's perspective
  def my_nodes
    @my_nodes ||= Set.new
  end

  def tree_period_mapping
    @tree_period_mapping ||= {
      dry: {"PLUM" => 8, "LEMON" => 8, "APPLE" => 9, "BANANA" => 6},
      wet: {"PLUM" => 3, "LEMON" => 3, "APPLE" => 2, "BANANA" => 4}
    }
  end

  def init_time_taken
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed_ms = ((t1 - init_start) * 1000.0).round
  end

  INIT_TIME = 950
  def init_time_remaining
    INIT_TIME - init_time_taken
  end

  # @return Numeric # in ms
  def turn_time_taken
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed_ms = ((t1 - t0) * 1000.0).round
  end

  # using a value somewhat lower than 50ms stated in rules for safety
  # @return Numeric # in ms
  TURN_TIME = 45
  def turn_time_remaining
    TURN_TIME - turn_time_taken
  end
end
