# :type, :x, :y, :size, :health, :fruits, :cooldown, :period
RSpec.describe Tree, instance_name: :tree do
  describe "#turns_till_size(size)" do
    subject(:turns_till_size) { tree.turns_till_size(size) }
    let(:size) { 4 }

    context "when asking about a size 1 plum to get to full" do
      let(:tree) { described_class.new("PLUM", 0, 0, 1, 1, 0, 8, 8) }
      # :size, :health, :fruits, :cooldown, :period

      it { is_expected.to eq(24) }
    end
    context "when asking about a size 1 plum with some turns already grown to get to full" do
      let(:tree) { described_class.new("PLUM", 0, 0, 1, 1, 0, 6, 8) }
      # :size, :health, :fruits, :cooldown, :period

      it { is_expected.to eq(22) }
    end
    context "when asking about a size 2 WET apple to get to 4" do
      let(:tree) { described_class.new("APPLE", 0, 0, 2, 1, 0, 2, 2) }
      # :size, :health, :fruits, :cooldown, :period

      it { is_expected.to eq(4) }
    end
    context "when asking about a size 2 WET apple with some growth done to get to 3" do
      let(:size) { 3 }
      let(:tree) { described_class.new("APPLE", 0, 0, 2, 1, 0, 1, 2) }
      # :size, :health, :fruits, :cooldown, :period

      it { is_expected.to eq(1) }
    end
    context "when asking a grown banana" do
      let(:tree) { described_class.new("BANANA", 0, 0, 4, 1, 1, 1, 2) }
      # :size, :health, :fruits, :cooldown, :period

      it { is_expected.to eq(0) }
    end
    context "when asking a grown apple FOR A SUB-4 growth time" do
      let(:size) { 2 }
      let(:tree) { described_class.new("BANANA", 0, 0, 4, 1, 1, 9, 9) }
      # :size, :health, :fruits, :cooldown, :period

      it { is_expected.to eq(0) }
    end
  end

  describe "#damaged?" do
    subject(:damaged?) { tree.damaged? }

    context "when it's a size 1 plum with HP below expected" do
      let(:tree) { Tree.new("PLUM", 0, 0, 1, 6-1, 0, 1, 8) }

      it { is_expected.to be(true) }
    end
    context "when it's a size 2 lemon with HP below expected" do
      let(:tree) { Tree.new("LEMON", 0, 0, 2, 8-1, 0, 1, 8) }

      it { is_expected.to be(true) }
    end
    context "when it's a size 3 apple with HP below expected" do
      let(:tree) { Tree.new("APPLE", 0, 0, 3, 17-1, 0, 1, 8) }

      it { is_expected.to be(true) }
    end
    context "when it's a size 4 banana with HP below expected" do
      let(:tree) { Tree.new("BANANA", 0, 0, 4, 6-1, 0, 1, 6) }

      it { is_expected.to be(true) }
    end
    context "when it's a size 1 apple with full HP" do
      let(:tree) { Tree.new("APPLE", 0, 0, 1, 11, 0, 1, 8) }

      it { is_expected.to be(false) }
    end
  end

  describe "#choppable_for_full_yield(chop_power)" do
    subject(:choppable_for_full_yield) { tree.choppable_for_full_yield(chop_power) }

    let(:chop_power) { 3 }

    context "when the tree is grown anyway" do
      let(:tree) { described_class.new("BANANA", 0, 0, 4, 6, 1, 1, 6) }

      it { is_expected.to be(true) }
    end

    context "when the tree is size 3 and will grow in 1 turn" do
      let(:tree) { described_class.new("BANANA", 0, 0, 3, 5, 0, 1, 6) }

      it { is_expected.to be(true) }
    end

    context "when the tree is size 3 and will grow in 2 turns with a chop power of 2" do
      let(:chop_power) { 2 }
      let(:tree) { described_class.new("BANANA", 0, 0, 3, 5, 0, 2, 6) }

      it { is_expected.to be(true) }
    end

    context "when the tree is size 2 and will grow in 1 turn" do
      let(:tree) { described_class.new("BANANA", 0, 0, 2, 4, 0, 1, 6) }

      it { is_expected.to be(false) }
    end
  end

  describe "#fruits_at_arrival(turns)" do
    subject(:fruits_at_arrival) { tree.fruits_at_arrival(turns) }

    context "when asking about a just-planted apple, the longest" do
      let(:tree) { described_class.new("APPLE", 0, 0, 1, 1, 0, 9, 9) }
      # :type, :x, :y, :size, :health, :fruits, :cooldown, :period

      it "returns correct timings", :aggregate_failures do
        expect(tree.fruits_at_arrival(0)).to eq(0)
        expect(tree.fruits_at_arrival(1)).to eq(0)
        expect(tree.fruits_at_arrival(35)).to eq(0)
        expect(tree.fruits_at_arrival(36)).to eq(1)
        expect(tree.fruits_at_arrival(45)).to eq(2)
        expect(tree.fruits_at_arrival(54)).to eq(3)
        expect(tree.fruits_at_arrival(63)).to eq(3) # no more than 3
      end
    end

    context "when asking about a wet banana" do
      let(:tree) { described_class.new("BANANA", 0, 0, 3, 1, 0, 1, 4) }

      it "returns correct timings", :aggregate_failures do
        expect(tree.fruits_at_arrival(0)).to eq(0)
        expect(tree.fruits_at_arrival(1)).to eq(0)
        expect(tree.fruits_at_arrival(4)).to eq(0)
        expect(tree.fruits_at_arrival(5)).to eq(1)
        expect(tree.fruits_at_arrival(9)).to eq(2)
        expect(tree.fruits_at_arrival(13)).to eq(3)
        expect(tree.fruits_at_arrival(20)).to eq(3) # no more than 3
      end
    end

    context "when asking about a wet PLUM" do
      let(:tree) { described_class.new("BANANA", 0, 0, 4, 1, 1, 2, 3) }
      # :type, :x, :y, :size, :health, :fruits, :cooldown, :period

      it "returns correct timings", :aggregate_failures do
        expect(tree.fruits_at_arrival(0)).to eq(1)
        expect(tree.fruits_at_arrival(1)).to eq(1)
        expect(tree.fruits_at_arrival(2)).to eq(2)
        expect(tree.fruits_at_arrival(3)).to eq(2)
        expect(tree.fruits_at_arrival(4)).to eq(2)
        expect(tree.fruits_at_arrival(5)).to eq(3)
        expect(tree.fruits_at_arrival(8)).to eq(3) # no more than 3
      end
    end
  end

  describe "#average_fruit_yield(distance_to_camp, worker_movespeed)" do
    subject(:average_fruit_yield) { tree.average_fruit_yield(distance, worker) }

    context "when asking for a n4 wet apple" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 2, 2) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 1 }
      let(:worker) { instance_double("Worker", move_speed: 1, carry_capacity: 1, harvest_power: 1) }

      it { is_expected.to eq(1/2.0) }
    end

    context "when asking for a n4 wet lemon" do
      let(:tree) { described_class.new("LEMON", 0, 0, 4, 4, 3, 3, 3) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 1 }
      let(:worker) { instance_double("Worker", move_speed: 1, carry_capacity: 1, harvest_power: 1) }

      it { is_expected.to eq(1/3.0) }
    end

    context "when asking for a 2-distance wet apple" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 2, 2) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 2 }
      let(:worker) { instance_double("Worker", move_speed: 1, carry_capacity: 1, harvest_power: 1) }

      # limiting factor is just minimum cycle length being 4
      it { is_expected.to eq(1/4.0) }
    end

    context "when asking for a 2-distance wet apple for a 2move worker" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 2, 2) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 2 }
      let(:worker) { instance_double("Worker", move_speed: 2, carry_capacity: 1, harvest_power: 1) }

      # same as 1-move worker since movespeed can not yet bring benefit
      it { is_expected.to eq(1/4.0) }
    end

    context "when asking for a 3-distance wet apple for a 1move worker" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 2, 2) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 3 }
      let(:worker) { instance_double("Worker", move_speed: 1, carry_capacity: 1, harvest_power: 1) }

      # same as 1-move worker since movespeed can not yet bring benefit
      it { is_expected.to eq(0.17) }
    end

    context "when asking for a 3-distance wet apple for a 2-move worker" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 2, 2) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 3 }
      let(:worker) { instance_double("Worker", move_speed: 2, carry_capacity: 1, harvest_power: 1) }

      it { is_expected.to eq(1/4.0) }
    end

    context "when asking for a n4 dry apple" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 9, 9) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 1 }
      let(:worker) { instance_double("Worker", move_speed: 1, carry_capacity: 1, harvest_power: 1) }

      it { is_expected.to eq(1/9.0) }
    end

    context "when asking for a 2-dist dry apple" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 9, 9) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 2 }
      let(:worker) { instance_double("Worker", move_speed: 1, carry_capacity: 1, harvest_power: 1) }

      # period is limiting factor
      it { is_expected.to eq(1/9.0) }
    end

    context "when asking for a 3-dist dry apple" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 9, 9) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 3 }
      let(:worker) { instance_double("Worker", move_speed: 2, carry_capacity: 1, harvest_power: 1) }

      # period is limiting factor
      it { is_expected.to eq(1/9.0) }
    end

    context "when asking for a faraway dry apple" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 9, 9) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 10 }
      let(:worker) { instance_double("Worker", move_speed: 2, carry_capacity: 2, harvest_power: 1) }

      # period is limiting factor
      it { is_expected.to eq(0.11) }
    end

    context "when asking for a faraway dry apple" do
      let(:tree) { described_class.new("APPLE", 0, 0, 4, 4, 3, 9, 9) }
       # :type, :x, :y, :size, :health, :fruits, :cooldown, :period
      let(:distance) { 10 }
      let(:worker) { instance_double("Worker", move_speed: 2, carry_capacity: 2, harvest_power: 2) }

      # period is limiting factor
      it { is_expected.to eq(0.11) }
    end
  end

  describe "#chop_turns(chop_speed)" do
    subject(:chop_turns) { tree.chop_turns(chop_speed) }

    context "when asking about a just-planted WET APPLE that has a lot of growth still in the tank" do
      let(:chop_speed) { 1 }
      let(:tree) { described_class.new("APPLE", 0, 0, 1, 11, 0, 2, 2) }
      # :size, :health, :fruits, :cooldown, :period

      it { is_expected.to eq(20) }
    end
    context "when asking about a just-planted WET APPLE, still growth outstrips chop" do
      let(:chop_speed) { 2 }
      let(:tree) { described_class.new("APPLE", 0, 0, 1, 11, 0, 2, 2) }

      it { is_expected.to eq(10) }
    end
    context "when asking about a WET PLUM where two growth spurts will occur" do
      let(:chop_speed) { 2 }
      let(:tree) { described_class.new("PLUM", 0, 0, 2, 8, 0, 1, 3) }
      # :size, :health, :fruits, :cooldown, :period

      it { is_expected.to eq(6) }
    end

    context "when asking about a size 1 banana" do
      let(:chop_speed) { 3 }
      let(:tree) { described_class.new("BANANA", 0, 0, 1, 3, 0, 6, 6) }
      # :size, :health, :fruits, :cooldown, :period

      it { is_expected.to eq(1) }
    end
    context "when asking about a size 1 banana that is about to grow" do
      let(:chop_speed) { 3 }
      let(:tree) { described_class.new("BANANA", 0, 0, 1, 3, 0, 1, 6) }
      # :size, :health, :fruits, :cooldown, :period

      it "returns 1 because chop is applied before growth and size increase will not apply" do
        is_expected.to eq(1)
      end
    end
  end
end

RSpec.describe Controller, instance_name: :controller do
  let(:controller) { described_class.new(field: field) }

  describe "#initialize" do
    context "when a field has camp" do
      let(:field) do
        <<~FIELD
          .....
          .0.1.
          .....
        FIELD
      end

      it "inits the grid such that camp can be left by trolls, but never returned to" do
        expect(controller.grid["1 0"]).to eq(["0 0", "2 0"].to_set)
        expect(controller.grid["0 1"]).to eq(["0 0", "0 2"].to_set)
        expect(controller.grid["1 1"].size).to eq(4)
      end
    end

    context "when a field has camps" do
      let(:field) do
        <<~FIELD
          ....
          0..1
          ....
        FIELD
      end

      it "inits the grid such that camp can be left by trolls, but never returned to" do
        expect(controller.my_camp.node).to eq("0 1")
        expect(controller.opp_camp.node).to eq("3 1")
      end
    end

    context "when field is from a real map" do
      let(:field) do
        <<~FIELD
          ...~~#.....##....#
          ...~~~~..+......~~
          .....~~0........~~
          .....~.#...#......
          ..................
          ......#...#.~.....
          ~~........1~~.....
          ~~......+..~~~~...
          #....##.....#~~...
        FIELD
      end

      it "inits fine" do
        expect(controller.send(:mining_nodes)).not_to be_nil
      end
    end
  end

  describe "#call(turn:, input:)" do
    subject(:call) { controller.call(**options) }

    let(:options) { {turn: turn, input: input} }
    let(:turn) { 1 }

    context "when initialized with seed=6972392475458301000 | Bronze lemon access" do
      let(:field) do
        <<~FIELD
          ~#...~~~..........
          ~~~..~~~.1..#.....
          ~~...~~.#.#.......
          .~~.............+.
          ...#.#..##..#.#...
          .+.............~~.
          .......#.#.~~...~~
          .....#..0.~~~..~~~
          ..........~~~...#~
        FIELD
      end

      let(:input) do
        <<~INPUT
          3 7 4 4 10 0
          3 7 4 4 10 0
          24
          PLUM 8 1 4 12 0 1
          PLUM 9 7 4 12 0 1
          PLUM 6 8 4 12 0 5
          PLUM 11 0 4 12 0 5
          PLUM 14 3 2 8 0 1
          PLUM 3 5 2 8 0 1
          LEMON 4 4 2 8 0 7
          LEMON 13 4 2 8 0 7
          LEMON 14 5 2 8 0 1
          LEMON 3 3 2 8 0 1
          LEMON 10 1 2 8 0 7
          LEMON 7 7 2 8 0 7
          APPLE 15 0 4 20 0 6
          APPLE 2 8 4 20 0 6
          APPLE 10 4 4 20 2 8
          APPLE 7 4 4 20 2 8
          APPLE 17 2 2 14 0 3
          APPLE 0 6 2 14 0 3
          BANANA 17 5 2 4 0 3
          BANANA 0 3 2 4 0 3
          BANANA 4 0 1 3 0 2
          BANANA 13 8 1 3 0 2
          BANANA 17 1 4 6 0 4
          BANANA 0 7 4 6 0 4
          2
          0 0 8 7 1 1 1 1 0 0 0 0 0 0
          1 1 9 1 1 1 1 1 0 0 0 0 0 0
        INPUT
      end

      it "returns a command to move to an open space near camp in prep for lemon pick" do
        is_expected.to eq("MOVE 0 8 8")
      end
    end

    context "when initialized with seed=6972392475458301000 | Just planted a lemon next to water on 9, 8" do
      let(:field) do
        <<~FIELD
          ~#...~~~..........
          ~~~..~~~.1..#.....
          ~~...~~.#.#.......
          .~~.............+.
          ...#.#..##..#.#...
          .+.............~~.
          .......#.#.~~...~~
          .....#..0.~~~..~~~
          ..........~~~...#~
        FIELD
      end

      let(:turn) { 4 }

      let(:input) do
        <<~INPUT
          3 6 4 4 10 0
          3 7 4 4 10 0
          26
          PLUM 8 1 4 12 1 3
          PLUM 9 7 4 12 2 3
          PLUM 6 8 4 12 0 1
          PLUM 11 0 4 12 0 1
          PLUM 14 3 3 10 0 5
          PLUM 3 5 3 10 0 5
          LEMON 4 4 2 8 0 3
          LEMON 13 4 2 8 0 3
          LEMON 14 5 4 12 0 3
          LEMON 3 3 4 12 0 3
          LEMON 10 1 2 8 0 3
          LEMON 7 7 2 8 0 3
          APPLE 15 0 4 20 0 2
          APPLE 2 8 4 20 0 2
          APPLE 10 4 4 20 2 4
          APPLE 7 4 4 20 2 4
          APPLE 17 2 3 17 0 8
          APPLE 0 6 3 17 0 8
          BANANA 17 5 3 5 0 3
          BANANA 0 3 3 5 0 3
          BANANA 4 0 2 4 0 2
          BANANA 13 8 2 4 0 2
          BANANA 17 1 4 6 1 6
          BANANA 0 7 4 6 1 6
          PLUM 8 0 1 6 0 3
          LEMON 9 8 1 6 0 3
          2
          0 0 9 8 1 1 1 1 0 0 0 0 0 0
          1 1 8 0 1 1 1 1 0 0 0 0 0 0
        INPUT
      end

      it "returns a command to move to a closeby harvestable plum while lemons are still at least 12 turns away" do
        is_expected.to eq("MSG trns till PLUM 2; MOVE 0 9 7")
      end
    end

    context "when initialized with seed=6972392475458301000 | Bronze lemon access, gather initial lemons" do
      let(:field) do
        <<~FIELD
          ~#...~~~..........
          ~~~..~~~.1..#.....
          ~~...~~.#.#.......
          .~~.............+.
          ...#.#..##..#.#...
          .+.............~~.
          .......#.#.~~...~~
          .....#..0.~~~..~~~
          ..........~~~...#~
        FIELD
      end

      let(:turn) { 4 }

      let(:input) do
        <<~INPUT
          8 6 4 4 10 0
          3 6 3 4 10 0
          27
          PLUM 8 1 4 12 3 0
          PLUM 9 7 4 12 0 1
          PLUM 6 8 4 12 2 6
          PLUM 11 0 4 12 2 6
          PLUM 14 3 4 12 0 2
          PLUM 3 5 4 12 0 2
          LEMON 4 4 4 12 0 8
          LEMON 13 4 4 12 0 8
          LEMON 14 5 4 12 3 1
          LEMON 3 3 4 12 3 1
          LEMON 10 1 4 12 0 8
          LEMON 7 7 4 12 0 8
          APPLE 15 0 4 20 2 9
          APPLE 2 8 4 20 2 9
          APPLE 10 4 4 20 3 2
          APPLE 7 4 4 20 3 2
          APPLE 17 2 4 20 0 6
          APPLE 0 6 4 20 0 6
          BANANA 17 5 4 6 2 4
          BANANA 0 3 4 6 2 4
          BANANA 4 0 4 6 1 3
          BANANA 13 8 4 6 1 3
          BANANA 17 1 4 6 2 1
          BANANA 0 7 4 6 2 1
          PLUM 8 0 4 12 0 1
          LEMON 9 8 4 12 0 1
          LEMON 10 0 1 6 0 1
          2
          0 0 9 7 1 1 1 1 0 0 0 0 0 0
          1 1 11 3 1 1 1 1 0 0 1 0 0 0
        INPUT
      end

      it "returns a command to move to a nearby about-to-produce lemon tree" do
        is_expected.to eq("MSG trns till LEMON 2; MOVE 0 9 8")
      end
    end

    context "when initialized with seed=6972392475458301000 | Just trained a chopper" do
      let(:field) do
        <<~FIELD
          ~#...~~~..........
          ~~~..~~~.1..#.....
          ~~...~~.#.#.......
          .~~.............+.
          ...#.#..##..#.#...
          .+.............~~.
          .......#.#.~~...~~
          .....#..0.~~~..~~~
          ..........~~~...#~
        FIELD
      end

      let(:turn) { 64 }

      let(:input) do
        <<~INPUT
          0 0 3 4 0 0
          4 0 3 4 2 0
          28
          PLUM 8 1 4 12 2 1
          PLUM 9 7 4 12 2 2
          PLUM 6 8 4 12 3 0
          PLUM 11 0 4 12 3 0
          PLUM 14 3 4 12 3 0
          PLUM 3 5 4 12 3 0
          LEMON 4 4 4 12 3 0
          LEMON 13 4 4 12 3 0
          LEMON 14 5 4 12 3 0
          LEMON 3 3 4 12 3 0
          LEMON 10 1 4 12 2 7
          LEMON 7 7 4 12 3 0
          APPLE 15 0 4 20 3 0
          APPLE 2 8 4 20 3 0
          APPLE 10 4 4 20 0 3
          APPLE 7 4 4 20 3 0
          APPLE 17 2 4 20 3 0
          APPLE 0 6 4 20 3 0
          BANANA 17 5 4 6 3 0
          BANANA 0 3 4 6 3 0
          BANANA 4 0 4 6 3 0
          BANANA 13 8 4 6 3 0
          BANANA 17 1 4 6 3 0
          BANANA 0 7 4 6 3 0
          PLUM 8 0 4 12 3 0
          LEMON 9 8 4 12 3 0
          LEMON 10 0 4 12 3 8
          APPLE 9 2 4 20 1 9
          5
          0 0 9 7 1 1 1 1 1 0 0 0 0 0
          1 1 10 3 1 1 1 1 0 0 1 0 0 0
          2 1 7 4 2 2 1 2 0 0 0 0 0 0
          3 1 9 0 1 2 1 1 0 0 0 0 0 0
          4 0 8 7 2 4 0 3 0 0 0 0 0 0
        INPUT
      end

      it "returns commands to chop the juiciest nearby spot for future bananas, and for helper to start planting bananas" do
        is_expected.to eq("MSG beeline; MOVE 4 9 7; DROP 0") # since helper 0 is trapped, remain to work where one is
      end
    end

    context "when initialized with seed=6972392475458301000 | when enough resources to train the chopper and helper is on 9 7 plum" do
      let(:turn) { 30 }

      let(:field) do
        <<~FIELD
          ~#...~~~..........
          ~~~..~~~.1..#.....
          ~~...~~.#.#.......
          .~~.............+.
          ...#.#..##..#.#...
          .+.............~~.
          .......#.#.~~...~~
          .....#..0.~~~..~~~
          ..........~~~...#~
        FIELD
      end

      let(:input) do
        <<~INPUT
          5 17 4 4 10 0
          1 0 1 4 2 0
          28
          PLUM 8 1 4 12 2 3
          PLUM 9 7 4 12 3 0
          PLUM 6 8 4 12 3 0
          PLUM 11 0 4 12 3 0
          PLUM 14 3 4 12 3 0
          PLUM 3 5 4 12 3 0
          LEMON 4 4 4 12 3 0
          LEMON 13 4 4 12 3 0
          LEMON 14 5 4 12 3 0
          LEMON 3 3 4 12 3 0
          LEMON 10 1 4 12 1 4
          LEMON 7 7 4 12 3 0
          APPLE 15 0 4 20 3 0
          APPLE 2 8 4 20 3 0
          APPLE 10 4 4 20 1 8
          APPLE 7 4 4 20 3 0
          APPLE 17 2 4 20 3 0
          APPLE 0 6 4 20 3 0
          BANANA 17 5 4 6 3 0
          BANANA 0 3 4 6 3 0
          BANANA 4 0 4 6 3 0
          BANANA 13 8 4 6 3 0
          BANANA 17 1 4 6 3 0
          BANANA 0 7 4 6 3 0
          PLUM 8 0 4 12 3 0
          LEMON 9 8 4 12 3 1
          LEMON 10 0 4 12 2 5
          APPLE 9 2 4 20 0 5
          4
          0 0 9 7 1 1 1 1 0 0 0 0 0 0
          1 1 9 2 1 1 1 1 0 0 0 0 0 0
          2 1 9 3 2 2 1 2 0 0 2 0 0 0
          3 1 8 1 1 2 1 1 2 0 0 0 0 0
        INPUT
      end

      it "returns a command to train chopper and for helper to pick a banana for planting" do
        is_expected.to eq("TRAIN 2 4 0 3; PICK 0 BANANA")
      end
    end

    context "when initialized with seed=4409877015551483400 | when two wet lemons are planted and now iron mining is in order" do
      let(:turn) { 15 } # at least

      let(:field) do
        <<~FIELD
          ..........~~#...
          ..~~..+..~~~~...
          ...~.0....~~~~..
          ...~.....~~~~...
          ...~~~~.....~...
          ..~~~~....1.~...
          ...~~~~..+..~~..
          ...#~~..........
        FIELD
      end

      let(:input) do
        <<~INPUT
          8 6 7 8 4 0
          2 2 5 8 2 0
          18
          PLUM 14 7 4 12 3 0
          PLUM 1 0 4 12 3 0
          PLUM 7 6 4 12 1 1
          PLUM 8 1 4 12 2 1
          LEMON 2 0 4 12 3 0
          LEMON 13 7 4 12 3 0
          APPLE 5 3 4 20 3 2
          APPLE 10 4 4 20 3 2
          APPLE 2 4 4 20 3 0
          APPLE 13 3 4 20 3 0
          BANANA 1 3 2 4 0 2
          BANANA 14 4 2 4 0 2
          BANANA 13 0 3 5 0 6
          BANANA 2 7 3 5 0 6
          LEMON 4 2 2 8 0 1
          LEMON 11 5 2 8 0 3
          LEMON 4 1 1 6 0 3
          PLUM 11 6 1 6 0 3
          3
          0 0 4 1 1 1 1 1 0 0 0 0 0 0
          1 1 11 6 1 1 1 1 0 0 0 0 0 0
          2 1 7 6 2 2 1 1 1 0 0 0 1 0
        INPUT
      end

      it "returns a command to go mining" do
        is_expected.to eq("MSG IROON!; MOVE 0 5 1")
      end
    end

    context "when seed=6892721188050253000 | no trees nearby" do
      let(:field) do
        <<~FIELD
          ~~........#~~~........
          ~~.........~~.1....#..
          ~~.+.......~#....+.#..
          ~...........#.......~~
          ......................
          #....................#
          ......................
          ~~.......#...........~
          ..#.+....#~.......+.~~
          ..#....0.~~.........~~
          ........~~~#........~~
        FIELD
      end

      let(:input) do
        <<~INPUT
          0 0 4 8 0 4
          3 2 2 10 2 0
          15
          PLUM 8 2 4 12 3 0
          PLUM 13 8 4 12 3 0
          LEMON 6 6 4 12 3 0
          LEMON 15 4 4 12 3 2
          APPLE 9 2 4 20 3 0
          APPLE 12 8 4 20 3 0
          BANANA 10 3 4 6 3 0
          BANANA 11 7 4 6 3 0
          BANANA 19 9 4 6 3 0
          BANANA 2 1 4 6 3 0
          LEMON 16 1 4 12 1 5
          APPLE 15 0 4 20 1 9
          PLUM 14 3 4 12 1 1
          PLUM 15 2 4 12 0 5
          BANANA 7 8 1 3 0 3
          5
          0 0 8 7 1 1 1 1 0 0 0 1 0 0
          1 1 14 2 1 1 1 1 0 0 0 0 0 0
          2 1 14 3 2 2 1 1 1 0 0 0 0 0
          3 1 15 1 1 3 1 1 0 0 0 0 0 0
          4 0 8 9 2 4 0 3 0 0 0 0 0 0
        INPUT
      end

      it "returns a command for chopper to beeline to closest grown tree" do
        is_expected.to start_with("MSG beeline; MOVE 4 8 7; MOVE 0")
      end

      context "when chopper outside base cells and near a choppable tree" do
        let(:input) do
          <<~INPUT
            0 0 4 5 0 8
            5 3 3 10 7 0
            17
            PLUM 8 2 4 12 3 0
            PLUM 13 8 4 12 3 0
            LEMON 15 4 4 12 3 0
            APPLE 9 2 4 20 3 0
            APPLE 12 8 4 20 3 0
            BANANA 10 3 4 6 3 0
            BANANA 11 7 4 6 3 0
            BANANA 19 9 4 6 3 0
            BANANA 2 1 4 6 3 0
            LEMON 16 1 4 12 2 8
            APPLE 15 0 4 20 1 5
            PLUM 14 3 4 12 2 4
            PLUM 15 2 4 12 2 8
            BANANA 7 8 3 5 0 2
            BANANA 8 9 3 5 0 2
            BANANA 8 8 2 4 0 5
            BANANA 7 7 1 3 0 3
            5
            0 0 6 8 1 1 1 1 0 0 0 1 0 0
            1 1 15 0 1 1 1 1 0 0 0 0 0 0
            2 1 15 2 2 2 1 1 0 0 0 0 0 0
            3 1 15 1 1 3 1 1 0 0 0 0 2 0
            4 0 6 3 2 4 0 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for chopper to continue on to grown tree, not turn back" do
          is_expected.to start_with("MSG beeline; MOVE 4 7 2; ") # or 8 3
        end
      end

      context "when we have been very efficient at clearing and only seed banana grown nearby" do
        <<~INPUT
          0 0 4 1 0 60
          17 10 7 10 13 0
          16
          PLUM 13 8 4 12 2 2
          LEMON 15 4 4 12 0 4
          APPLE 9 2 4 20 3 0
          APPLE 12 8 4 20 3 0
          BANANA 10 3 4 6 3 0
          BANANA 11 7 4 6 3 0
          BANANA 19 9 4 6 3 0
          BANANA 2 1 4 6 3 0
          LEMON 16 1 4 12 0 5
          APPLE 15 0 4 20 0 1
          PLUM 14 3 4 12 1 8
          PLUM 15 2 4 12 2 5
          BANANA 8 9 4 6 3 0
          BANANA 7 8 3 5 0 4
          BANANA 8 8 2 4 0 4
          BANANA 7 7 1 3 0 4
          6
          0 0 8 8 1 1 1 1 0 0 0 0 0 0
          1 1 14 3 1 1 1 1 0 0 0 0 0 0
          2 1 15 1 2 2 1 1 0 1 0 0 0 0
          3 1 15 3 1 3 1 1 0 1 0 0 0 0
          4 0 7 8 2 4 0 3 0 0 0 0 0 0
          5 1 16 0 2 3 1 2 0 0 0 0 0 0
        INPUT

        it "returns a command to go cut outside base, not seed banana" do
          is_expected.to start_with("MSG beeline; MOVE 4 8 7; ") # or 7 6
        end
      end

      context "its the end of the game, time to harvest even seed tree and everything else" do
        let(:turn) { 288 }

        let(:input) do
          <<~INPUT
            0 0 4 1 0 144
            9 1 2 0 0 67
            16
            PLUM 13 8 4 12 3 0
            APPLE 12 8 4 15 3 0
            BANANA 19 9 4 6 3 0
            BANANA 2 1 4 6 3 0
            BANANA 8 9 4 6 3 1
            BANANA 19 8 4 6 1 2
            BANANA 8 8 3 5 0 2
            BANANA 19 3 4 6 0 1
            BANANA 18 7 3 5 0 5
            BANANA 15 0 2 4 0 4
            BANANA 7 7 2 4 0 5
            BANANA 20 4 2 2 0 2
            BANANA 19 0 1 3 0 1
            BANANA 15 2 1 3 0 2
            BANANA 21 4 2 4 0 4
            BANANA 8 7 1 3 0 6
            7
            0 0 8 7 1 1 1 1 0 0 0 0 0 0
            1 1 13 3 1 1 1 1 0 0 0 1 0 0
            2 1 19 5 2 2 1 1 0 0 0 0 0 0
            3 1 17 6 1 3 1 1 0 0 0 2 0 0
            4 0 7 8 2 4 0 3 0 0 0 0 0 0
            5 1 18 1 2 3 1 2 0 0 0 0 0 2
            6 1 15 2 3 3 1 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to go cut largest tree, including seed, which is the biggest" do
          is_expected.to start_with("MSG fullclear; MOVE 4 8 9")
        end
      end

      context "its the end of the game, time for helper to get out of the way" do
        let(:turn) { 290 }

        let(:input) do
          <<~INPUT
            0 0 4 1 0 144
            9 1 2 0 0 67
            15
            PLUM 13 8 4 12 3 0
            APPLE 12 8 4 15 3 0
            BANANA 19 9 4 6 3 0
            BANANA 2 1 4 6 3 0
            BANANA 8 9 4 6 3 0
            BANANA 19 8 4 6 1 2
            BANANA 8 8 3 5 0 2
            BANANA 19 3 4 6 0 1
            BANANA 18 7 3 5 0 5
            BANANA 15 0 2 4 0 4
            BANANA 7 7 2 4 0 5
            BANANA 20 4 2 2 0 2
            BANANA 19 0 1 3 0 1
            BANANA 15 2 1 3 0 2
            BANANA 21 4 2 4 0 4
            7
            0 0 8 9 1 1 1 1 0 0 0 0 0 0
            1 1 13 3 1 1 1 1 0 0 0 1 0 0
            2 1 19 5 2 2 1 1 0 0 0 0 0 0
            3 1 17 6 1 3 1 1 0 0 0 2 0 0
            4 0 7 8 2 4 0 3 0 0 0 0 0 0
            5 1 18 1 2 3 1 2 0 0 0 0 0 2
            6 1 15 2 3 3 1 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to go cut largest tree, including seed, which is the biggest" do
          is_expected.to start_with("MSG fullclear; MOVE 4 8 9; MOVE 0 8 8")
        end
      end
    end

    context "when seed=-4262217784875278300" do
      let(:field) do
        <<~FIELD
          ..~~.........~~~
          ..~~~.+..#..~~~.
          ..~~~....#..~~..
          .........1......
          ......0.........
          ..~~..#....~~~..
          .~~~..#..+.~~~..
          ~~~.........~~..
        FIELD
      end

      context "when there's a timeout likely due to tons of trees" do
        let(:input) do
          <<~INPUT
            5 0 5 5 0 8
            12 9 8 20 5 0
            31
            PLUM 10 1 4 12 3 0
            PLUM 5 6 4 12 3 0
            PLUM 15 2 4 12 3 0
            PLUM 0 5 4 12 3 0
            PLUM 10 7 4 12 3 0
            PLUM 5 0 4 12 3 0
            LEMON 4 7 4 12 3 0
            LEMON 11 0 4 12 3 0
            APPLE 8 7 4 20 3 0
            APPLE 7 0 4 20 3 0
            APPLE 14 4 4 20 3 0
            APPLE 1 3 4 20 3 0
            BANANA 7 3 4 3 2 5
            BANANA 7 2 4 6 3 0
            BANANA 8 5 4 6 3 0
            BANANA 7 1 4 6 3 0
            BANANA 8 6 4 6 3 0
            PLUM 10 2 4 12 0 4
            LEMON 10 0 4 12 3 0
            LEMON 9 0 4 12 3 0
            APPLE 8 1 4 20 1 4
            LEMON 11 3 4 12 0 1
            PLUM 11 2 4 12 3 0
            APPLE 12 4 4 20 3 0
            APPLE 11 4 4 20 3 0
            BANANA 5 4 3 5 0 1
            APPLE 10 4 2 5 0 2
            BANANA 5 3 3 5 0 4
            BANANA 5 2 2 4 0 1
            BANANA 6 3 1 3 0 5
            BANANA 8 4 1 2 0 5
            5
            0 0 6 3 1 1 1 1 0 0 0 1 0 0
            1 1 8 4 1 1 1 1 0 0 0 0 0 0
            2 1 7 3 2 2 1 0 0 0 0 2 0 0
            3 1 10 3 2 2 1 0 2 0 0 0 0 0
            4 0 7 4 2 4 0 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a command in time" do
          is_expected.to start_with("MSG chop warz; MOVE 4 8 4")
        end
      end
    end

    context "with seed=388785412389555300, far iron, lots of nearby water" do
      let(:field) do
        <<~FIELD
          ...#...#..........~...
          .##...........0...~...
          ..............~~~.#...
          ....~~~~~...~~~~~~#.+.
          ...+~~~~~...~~~~~~~...
          ...~~~~~~....~~~~~~...
          ...~~~~~~~...~~~~~+...
          .+.#~~~~~~...~~~~~....
          ...#.~~~..............
          ...~...1...........##.
          ...~..........#...#...
        FIELD
      end

      context "when start and field mean one worker is not enough to go for chopper and an intermediate worker is needed" do
        let(:input) do
          <<~INPUT
            10 6 9 9 3 0
            10 6 9 9 3 0
            16
            PLUM 14 8 3 10 0 3
            PLUM 7 2 3 10 0 3
            LEMON 9 4 4 12 3 3
            LEMON 12 6 4 12 3 3
            LEMON 19 1 4 12 3 2
            LEMON 2 9 4 12 3 2
            APPLE 13 8 3 17 0 1
            APPLE 8 2 3 17 0 1
            APPLE 17 8 1 11 0 2
            APPLE 4 2 1 11 0 2
            APPLE 16 0 1 11 0 9
            APPLE 5 10 1 11 0 9
            BANANA 12 7 4 6 0 4
            BANANA 9 3 4 6 0 4
            BANANA 19 6 4 6 3 5
            BANANA 2 4 4 6 3 5
            2
            0 1 7 9 1 1 1 1 0 0 0 0 0 0
            1 0 14 1 1 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to train a decent intermediate worker" do
          is_expected.to eq("TRAIN 3 2 2 1; MOVE 1 15 1")
        end
      end

      context "when intermediate worker has just appeared" do
        let(:input) do
          <<~INPUT
            1 1 4 9 1 0
            10 6 9 9 3 0
            16
            PLUM 14 8 3 10 0 2
            PLUM 7 2 3 10 0 2
            LEMON 9 4 4 12 3 2
            LEMON 12 6 4 12 3 2
            LEMON 19 1 4 12 3 1
            LEMON 2 9 4 12 3 1
            APPLE 13 8 4 20 0 2
            APPLE 8 2 4 20 0 2
            APPLE 17 8 1 11 0 1
            APPLE 4 2 1 11 0 1
            APPLE 16 0 1 11 0 8
            APPLE 5 10 1 11 0 8
            BANANA 12 7 4 6 0 3
            BANANA 9 3 4 6 0 3
            BANANA 19 6 4 6 3 4
            BANANA 2 4 4 6 3 4
            3
            0 1 8 9 1 1 1 1 0 0 0 0 0 0
            1 0 15 1 1 1 1 1 0 0 0 0 0 0
            2 0 14 1 3 2 2 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for inter to get iron (hard left) and helper to pick up a lemon to plant" do
          is_expected.to eq("MSG IROON!; PICK 1 LEMON; MOVE 2 11 1")
        end
      end

      context "when helper has just picked up a banana" do
        let(:input) do
          <<~INPUT
            1 1 4 8 1 0
            4 1 7 9 1 0
            17
            PLUM 14 8 4 12 0 2
            PLUM 7 2 4 12 0 2
            LEMON 9 4 4 12 3 0
            LEMON 12 6 4 12 3 0
            LEMON 19 1 4 12 3 0
            LEMON 2 9 4 12 3 0
            APPLE 13 8 4 20 1 1
            APPLE 8 2 4 20 1 1
            APPLE 17 8 3 17 0 2
            APPLE 4 2 3 17 0 2
            APPLE 16 0 1 11 0 5
            APPLE 5 10 1 11 0 5
            BANANA 12 7 4 6 1 4
            BANANA 9 3 4 6 1 4
            BANANA 19 6 4 6 3 1
            BANANA 2 4 4 6 3 1
            LEMON 15 1 1 6 0 2
            4
            0 1 8 9 1 1 1 1 1 0 0 0 0 0
            1 0 15 1 1 1 1 1 0 0 0 1 0 0
            2 0 5 1 3 2 2 1 0 0 0 0 0 0
            3 1 10 8 2 2 1 1 0 0 0 0 0 0
          INPUT
        end

        xit "returns a command for helper to go plant closer to seed in prep for lemon gathering" do
          # is_expected.to eq("MSG trns till PLUM 3; MOVE 1 16 1; MOVE 2 7 2")
          is_expected.to eq("MSG IROON!; MOVE 1 16 1; MOVE 2 3 2")
        end
      end

      context "when helper should get to about-to-fruit lemon" do
        let(:input) do
          <<~INPUT
            1 1 4 6 3 0
            1 1 7 9 1 0
            23
            PLUM 14 8 4 12 3 2
            PLUM 7 2 4 12 3 2
            LEMON 9 4 4 12 3 0
            LEMON 12 6 4 12 3 0
            LEMON 19 1 4 12 3 0
            LEMON 2 9 4 12 3 0
            APPLE 13 8 4 20 3 0
            APPLE 8 2 4 20 3 0
            APPLE 17 8 4 20 3 1
            APPLE 4 2 4 20 3 1
            APPLE 16 0 2 14 0 5
            APPLE 5 10 2 14 0 5
            BANANA 12 7 4 6 3 3
            BANANA 9 3 4 6 3 3
            BANANA 19 6 4 6 3 0
            BANANA 2 4 4 6 3 0
            LEMON 15 1 4 12 0 2
            PLUM 8 9 2 8 0 8
            BANANA 16 1 2 4 0 1
            PLUM 7 10 1 6 0 4
            BANANA 15 0 1 3 0 3
            BANANA 14 0 1 3 0 6
            LEMON 6 9 1 6 0 3
            4
            0 1 6 9 1 1 1 1 0 0 0 0 0 0
            1 0 14 0 1 1 1 1 0 0 0 0 0 0
            2 0 13 1 3 2 2 1 0 0 0 0 0 0
            3 1 15 8 2 2 1 1 0 0 0 0 2 0
          INPUT
        end

        xit "returns a command for helper to go get ready for lemon harvesting" do
          is_expected.to eq("MSG IROON!, trns till LEMON 3; MOVE 2 10 1; MOVE 1 15 0")
        end
      end

      context "when inter has just dropped off final iron and plums should be gathered" do
        let(:input) do
          <<~INPUT
            0 14 4 7 11 0
            6 5 6 9 6 0
            24
            PLUM 14 8 4 12 3 0
            PLUM 7 2 4 12 3 0
            LEMON 9 4 4 12 3 0
            LEMON 12 6 4 12 3 0
            LEMON 19 1 4 12 3 0
            LEMON 2 9 4 12 3 0
            APPLE 13 8 4 20 3 0
            APPLE 8 2 4 20 3 0
            APPLE 17 8 4 20 3 0
            APPLE 4 2 4 20 3 0
            APPLE 16 0 4 20 3 6
            APPLE 5 10 4 20 3 6
            BANANA 12 7 4 6 3 0
            BANANA 9 3 4 6 3 0
            BANANA 19 6 4 6 3 0
            BANANA 2 4 4 6 3 0
            LEMON 15 1 4 12 1 3
            PLUM 8 9 4 12 1 4
            BANANA 16 1 4 6 3 0
            PLUM 7 10 4 12 2 8
            BANANA 15 0 4 6 3 0
            LEMON 6 9 4 12 2 1
            LEMON 8 8 4 12 1 2
            APPLE 8 10 3 17 0 8
            4
            0 1 8 8 1 1 1 1 0 1 0 0 0 0
            1 0 15 1 1 1 1 1 0 0 0 0 0 0
            2 0 13 1 3 2 2 1 0 0 0 0 0 0
            3 1 6 9 2 2 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for inter to go grab plums" do
          is_expected.to eq("MSG oh LEMON, getting seed PLUM; HARVEST 1; MOVE 2 10 1")
        end
      end

      context "when inter has just dropped off final iron and plums should be gathered" do
        let(:input) do
          <<~INPUT
            8 20 2 7 0 40
            1 23 5 5 1 14
            31
            PLUM 14 8 4 12 3 0
            PLUM 7 2 4 12 3 0
            LEMON 9 4 4 12 3 0
            LEMON 12 6 4 12 3 0
            LEMON 19 1 4 12 3 0
            LEMON 2 9 4 12 3 0
            APPLE 13 8 4 20 3 0
            APPLE 8 2 4 20 3 0
            APPLE 17 8 4 20 3 0
            APPLE 4 2 4 20 3 0
            APPLE 5 10 4 4 3 0
            BANANA 12 7 4 6 3 0
            BANANA 9 3 4 6 3 0
            BANANA 19 6 4 6 3 0
            BANANA 2 4 4 6 3 0
            LEMON 15 1 4 9 3 0
            BANANA 16 1 4 6 3 4
            PLUM 12 2 4 12 1 2
            LEMON 9 9 4 12 0 1
            LEMON 6 10 4 12 0 3
            BANANA 9 8 4 6 1 2
            APPLE 7 10 3 9 0 3
            BANANA 8 8 4 6 2 4
            BANANA 14 0 3 5 0 4
            APPLE 8 9 2 14 0 4
            APPLE 9 10 2 14 0 6
            BANANA 17 1 3 5 0 4
            BANANA 10 9 2 4 0 5
            BANANA 8 10 1 3 0 2
            BANANA 15 0 1 3 0 3
            BANANA 5 9 1 3 0 4
            7
            0 1 8 10 1 1 1 1 0 0 0 1 0 0
            1 0 16 1 1 1 1 1 0 0 0 1 0 0
            2 0 13 1 3 2 2 1 0 0 0 0 0 0
            3 1 5 9 2 2 1 1 0 0 0 0 0 0
            4 1 5 10 2 2 1 2 0 0 0 0 0 0
            5 0 15 1 2 4 0 3 0 0 0 0 0 0
            6 1 7 10 2 3 0 2 0 0 0 0 0 0
          INPUT
        end

        # Tricky case, nearby 15 1 lemon is already being chopped by chopper, so
        # it's a choice between 8 2 apple and 9 3 banana, prefer apple, cuz it has quicker period
        it "returns a command for inter to go to harass opp" do
          is_expected.to eq("MSG hee hee; CHOP 5; MOVE 1 16 0; MOVE 2 10 1")
        end
      end

      context "when helper has two ways to get to diagonal seed at 16 1 and one is blocked by chopper" do
        let(:input) do
          <<~INPUT
            6 4 2 7 0 12
            7 25 6 9 4 0
            27
            PLUM 14 8 4 12 3 0
            PLUM 7 2 4 12 3 0
            LEMON 9 4 4 12 3 0
            LEMON 12 6 4 12 3 0
            LEMON 19 1 4 12 3 0
            LEMON 2 9 4 12 3 0
            APPLE 13 8 4 20 3 0
            APPLE 8 2 4 20 3 0
            APPLE 17 8 4 20 3 0
            APPLE 4 2 4 20 3 0
            APPLE 16 0 4 17 3 0
            APPLE 5 10 4 20 3 6
            BANANA 12 7 4 6 3 0
            BANANA 9 3 4 6 3 0
            BANANA 19 6 4 6 3 0
            BANANA 2 4 4 6 3 0
            LEMON 15 1 4 12 1 2
            PLUM 8 9 4 12 3 6
            BANANA 16 1 4 6 3 1
            PLUM 7 10 4 12 3 0
            PLUM 12 2 4 12 3 1
            LEMON 6 9 4 12 1 3
            LEMON 8 8 4 12 3 1
            APPLE 8 10 4 20 3 0
            BANANA 13 0 3 5 0 2
            BANANA 17 1 2 4 0 3
            BANANA 15 0 1 3 0 6
            6
            0 1 8 9 1 1 1 1 0 0 0 0 0 0
            1 0 15 0 1 1 1 1 0 0 0 0 0 0
            2 0 13 0 3 2 2 1 0 0 0 0 0 0
            3 1 6 9 2 2 1 1 0 1 0 0 0 0
            4 1 8 10 2 2 1 2 0 0 0 0 2 0
            5 0 16 0 2 4 0 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for helper to take the other available path" do
          is_expected.to eq("MSG hee hee; CHOP 5; MOVE 1 15 1; MOVE 2 10 0")
        end
      end
    end

    context "with seed=4528739156648955000" do

      let(:field) do
        <<~FIELD
          ...........~~~~~....
          ..#..........~~~~~~.
          +.....~~~....~~~~~~.
          ......~~.....~~~.~..
          ......~.1..#.~~....+
          +....~~.#..0.~......
          ..~.~~~.....~~......
          .~~~~~~....~~~.....+
          .~~~~~~..........#..
          ....~~~~~...........
        FIELD
      end

      context "when only iron remains ungathered" do
        let(:turn) { 66 }
        let(:input) do
          <<~INPUT
            6 18 6 7 6 0
            3 3 6 33 6 0
            18
            PLUM 4 1 4 12 3 0
            PLUM 15 8 4 12 3 0
            PLUM 1 9 4 12 3 0
            PLUM 18 0 4 12 3 0
            LEMON 9 8 4 12 3 0
            LEMON 10 1 4 12 3 0
            LEMON 0 0 4 12 3 0
            LEMON 19 9 4 12 3 0
            APPLE 2 4 4 20 3 0
            APPLE 17 5 4 20 3 0
            BANANA 9 5 4 6 3 0
            BANANA 10 4 4 6 3 0
            LEMON 12 5 4 12 0 1
            BANANA 12 4 4 6 3 0
            BANANA 8 3 4 6 0 2
            BANANA 12 3 4 6 3 0
            BANANA 7 4 4 6 1 3
            PLUM 10 7 4 12 3 0
            4
            0 1 8 3 1 1 1 1 0 0 0 0 0 0
            1 0 12 5 1 1 1 1 0 0 0 0 0 0
            2 1 7 4 1 1 1 0 0 0 0 0 0 0
            3 0 14 7 2 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to train good-enough -1chop chopper" do
          is_expected.to eq("MSG hee hee; TRAIN 2 4 0 2; MOVE 1 12 4; MOVE 3 13 8")
        end
      end
    end

    context "with seed=1236240287580781800" do
      let(:field) do
        <<~FIELD
          ..~~~+.........#..~...
          ..~~~~~.......#...~...
          ......~.~~~......#~#..
          .+..#.~~~~~~.0........
          .....~~~~.~~..........
          .......~......~.......
          ..........~~.~~~~.....
          ........1.~~~~~~.#..+.
          ..#~#......~~~.~......
          ...~...#.......~~~~~..
          ...~..#.........+~~~..
        FIELD
      end

      context "when helper is already on a fruit-having tree of a type we need" do
        let(:turn) { 15 }

        let(:input) do
          <<~INPUT
            3 0 1 4 4 0
            9 3 3 6 6 0
            18
            PLUM 1 9 4 12 0 6
            PLUM 20 1 4 12 0 6
            LEMON 16 5 4 12 3 0
            LEMON 5 5 4 12 3 0
            APPLE 1 7 4 20 3 0
            APPLE 20 3 4 20 3 0
            APPLE 4 9 4 20 3 0
            APPLE 17 1 4 20 3 0
            APPLE 7 0 4 20 0 3
            APPLE 14 10 4 20 0 3
            BANANA 10 9 4 6 3 0
            BANANA 11 1 4 6 3 0
            BANANA 4 6 4 6 3 2
            BANANA 17 4 4 6 3 2
            PLUM 12 3 4 12 1 3
            BANANA 12 4 3 5 0 3
            LEMON 14 4 3 10 0 2
            BANANA 13 4 1 3 0 2
            3
            0 1 5 5 1 1 1 1 0 0 0 0 0 0
            1 0 12 3 1 1 1 1 0 0 0 0 0 0
            2 0 18 4 2 1 1 1 0 0 0 0 1 0
          INPUT
        end

        it "returns a simple command to harvest it" do
          is_expected.to eq("MSG oh PLUM; HARVEST 1; MOVE 2 17 3")
        end
      end

      context "when helper is already harvesting lemon diligently" do
        let(:turn) { 15 }

        let(:input) do
          <<~INPUT
            4 1 1 4 5 0
            9 3 3 6 6 0
            19
            PLUM 1 9 4 12 1 6
            PLUM 20 1 4 12 1 6
            LEMON 16 5 4 12 3 0
            LEMON 5 5 4 12 3 0
            APPLE 1 7 4 20 3 0
            APPLE 20 3 4 20 3 0
            APPLE 4 9 4 20 3 0
            APPLE 17 1 4 20 3 0
            APPLE 7 0 4 20 1 4
            APPLE 14 10 4 20 1 4
            BANANA 10 9 4 6 3 0
            BANANA 11 1 4 6 3 0
            BANANA 4 6 4 6 3 0
            BANANA 17 4 4 6 3 0
            PLUM 12 3 4 12 2 1
            BANANA 12 4 4 6 1 3
            LEMON 14 4 4 12 1 3
            BANANA 13 4 3 5 0 6
            LEMON 6 5 2 8 0 1
            3
            0 1 7 6 1 1 1 1 0 1 0 0 0 0
            1 0 14 4 1 1 1 1 0 0 0 0 0 0
            2 0 14 3 2 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a simple command to have inter do something else, like go for plums" do
          is_expected.to eq("MSG oh LEMON, trns till PLUM 3; HARVEST 1; MOVE 2 13 2")
        end
      end

      context "when helper is already harvesting lemon and some apples are missing" do
        let(:turn) { 45 }

        let(:input) do
          <<~INPUT
            6 18 1 4 11 0
            4 2 1 6 4 0
            19
            PLUM 1 9 4 12 3 0
            PLUM 20 1 4 12 3 0
            LEMON 16 5 4 12 3 0
            LEMON 5 5 4 12 3 0
            APPLE 1 7 4 20 3 0
            APPLE 20 3 4 20 3 0
            APPLE 4 9 4 20 3 0
            APPLE 17 1 4 20 3 0
            APPLE 7 0 4 20 3 0
            APPLE 14 10 4 20 3 0
            BANANA 10 9 4 6 3 0
            BANANA 11 1 4 6 3 0
            BANANA 4 6 4 6 3 0
            BANANA 17 4 4 6 3 0
            PLUM 12 3 4 12 3 0
            BANANA 12 4 4 6 3 0
            LEMON 14 4 4 12 1 2
            BANANA 13 4 4 6 2 2
            LEMON 6 5 4 12 3 0
            4
            0 1 6 6 1 1 1 1 0 1 0 0 0 0
            1 0 14 4 1 1 1 1 0 0 0 0 0 0
            2 0 14 3 2 1 1 1 0 0 0 0 0 0
            3 1 6 5 2 2 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a simple command to have inter go for closest apple at 17 1" do
          is_expected.to eq("MSG IROON!, trns till APPLE 4; MOVE 1 15 4; MOVE 2 16 3")
        end
      end

      context "when helper is already harvesting lemon" do
        let(:turn) { 145 }

        let(:input) do
          <<~INPUT
            0 1 0 9 0 0
            3 8 2 6 1 4
            24
            PLUM 1 9 4 12 3 0
            PLUM 20 1 4 12 3 0
            LEMON 16 5 4 12 3 0
            LEMON 5 5 4 12 3 0
            APPLE 1 7 4 20 3 0
            APPLE 20 3 4 20 3 0
            APPLE 4 9 4 20 3 0
            APPLE 17 1 4 17 3 0
            APPLE 7 0 4 20 3 0
            APPLE 14 10 4 20 3 0
            BANANA 10 9 4 6 3 0
            BANANA 11 1 4 6 3 0
            BANANA 4 6 4 6 3 0
            BANANA 17 4 4 6 3 0
            BANANA 12 4 4 6 3 0
            BANANA 13 4 4 3 0 1
            LEMON 6 5 4 12 3 0
            LEMON 7 6 4 12 3 0
            APPLE 4 10 4 20 3 0
            APPLE 3 7 4 20 2 1
            APPLE 2 9 4 20 3 0
            PLUM 4 4 4 12 3 0
            LEMON 8 5 4 12 3 3
            LEMON 9 6 4 12 0 2
            6
            0 1 6 5 1 1 1 1 1 0 0 0 0 0
            1 0 12 4 1 1 1 1 0 0 0 0 0 0
            2 0 16 5 2 1 1 1 0 0 0 0 0 0
            3 1 17 1 2 2 1 1 0 1 0 0 0 0
            4 1 3 7 2 2 1 1 0 0 2 0 0 0
            5 0 13 4 2 4 0 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a simple command to have inter go harass opp" do
          is_expected.to eq("MSG hee hee; CHOP 5; HARVEST 1; MOVE 2 16 3")
        end
      end
    end

    context "with seed=4208699414688448500" do
      let(:field) do
        <<~FIELD
          .~##...+..~....#
          .~+..#....~~....
          ......#...~.#...
          ....1...........
          ...........0....
          ...#.~...#......
          ....~~....#..+~.
          #....~..+...##~.
        FIELD
      end

      context "when its endgame, I am leading superbly" do
        let(:input) do
          <<~INPUT
            14 13 6 0 1 84
            5 8 4 3 0 68
            3
            APPLE 14 3 4 20 1 4
            BANANA 10 4 3 5 0 4
            BANANA 10 3 1 3 0 3
            6
            0 1 8 3 1 1 1 1 0 0 0 0 0 0
            1 0 10 4 1 1 1 1 0 0 0 0 0 0
            2 0 11 3 1 2 1 2 0 0 0 0 0 0
            3 1 5 3 2 2 2 2 0 0 0 0 0 2
            4 1 10 4 3 3 0 3 0 0 0 0 0 2
            5 0 11 5 2 4 0 3 0 0 0 0 0 2
          INPUT
        end

        it "returns commands to chop everything down" do
          is_expected.to eq("MSG endgame; DROP 5; CHOP 1; MOVE 2 10 3")
        end
      end
    end

    context "with seed=" do
      let(:field) do
        <<~FIELD
          ..~~.......~~....#..
          ..~~.......~~##...#.
          #.........~~#.......
          +#........~~......#.
          ...1...#..........#.
          .#..........#...0...
          .#......~~........#+
          .......#~~.........#
          .#...##~~.......~~..
          ..#....~~.......~~..
        FIELD
      end

      context "when just trained the chopper" do
        let(:input) do
          <<~INPUT
            0 1 0 9 0 0
            8 12 1 27 4 0
            21
            PLUM 15 9 4 12 3 0
            PLUM 4 0 4 12 3 0
            PLUM 19 2 4 12 3 0
            PLUM 0 7 4 12 3 0
            PLUM 6 1 4 12 3 0
            PLUM 13 8 4 12 3 0
            LEMON 16 6 4 12 3 0
            LEMON 3 3 4 12 1 5
            LEMON 3 9 4 12 3 0
            LEMON 16 0 4 12 3 0
            APPLE 17 3 4 20 3 0
            APPLE 2 6 4 20 3 0
            BANANA 8 3 4 6 3 0
            BANANA 11 6 4 6 3 0
            BANANA 13 5 4 6 3 0
            BANANA 6 4 4 6 3 0
            BANANA 12 6 4 6 3 0
            BANANA 7 3 4 6 3 0
            LEMON 16 7 4 12 3 0
            BANANA 4 4 4 6 0 1
            PLUM 14 5 4 12 2 7
            5
            0 1 4 3 1 1 1 1 0 0 0 0 0 0
            1 0 17 5 1 1 1 1 0 0 0 1 0 0
            2 1 3 3 1 1 1 0 1 0 0 0 0 0
            3 0 19 4 1 1 1 1 0 0 0 0 0 0
            4 0 16 5 2 4 0 3 0 0 0 0 0 0
          INPUT
        end

        it "times out, seek to optim" do
          is_expected.to eq("MSG beeline, hee hee; MOVE 4 16 6; PLANT 1 BANANA; MOVE 3 19 5")
        end
      end
    end

    context "with seed=-175587185154855230" do
      let(:field) do
        <<~FIELD
          ......#......~~.......
          .............~~..~....
          .~~.........1~...~~~~.
          ~~~....#...+.~....~~~~
          ~~~.................~~
          ~~..................~~
          ~~.................~~~
          ~~~~....~.+...#....~~~
          .~~~~...~0.........~~.
          ....~..~~.............
          .......~~......#......
        FIELD
      end

      context "when opp just chopped my tree" do
        let(:input) do
          <<~INPUT
            6 14 7 8 10 0
            1 0 6 5 0 3
            19
            PLUM 19 1 4 12 3 0
            PLUM 2 9 4 12 3 0
            LEMON 9 7 4 9 1 3
            LEMON 11 0 4 12 3 0
            LEMON 10 10 4 12 3 0
            LEMON 18 8 4 12 3 0
            LEMON 3 2 4 12 3 0
            APPLE 0 9 4 20 3 9
            APPLE 21 1 4 20 3 9
            APPLE 6 4 4 20 3 0
            APPLE 15 6 4 20 3 0
            APPLE 16 8 4 20 3 0
            APPLE 5 2 4 20 3 0
            BANANA 14 5 4 6 2 1
            BANANA 7 5 4 6 2 1
            BANANA 6 8 4 6 3 0
            BANANA 15 2 4 6 3 0
            BANANA 12 4 2 4 0 3
            BANANA 11 2 1 3 0 4
            3
            0 0 9 7 1 1 1 1 0 0 0 0 0 0
            1 1 11 1 1 1 1 1 0 0 0 1 0 0
            2 1 9 7 2 3 0 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to NOT help the chop, but harvest needed lemon instead" do
          is_expected.to eq("HARVEST 0")
        end
      end
    end

    context "when synthetic setup for chop wars with bag emptying" do
      let(:field) do
        <<~FIELD
          .+1
          ...
          0+.
        FIELD
      end

      let(:input) do
        <<~INPUT
          6 14 7 8 10 0
          1 0 6 5 0 3
          3
          LEMON 0 0 4 8 3 0
          PLUM 1 1 4 12 3 0
          LEMON 2 2 4 12 0 3
          2
          0 0 0 1 1 1 1 1 0 0 1 0 0 0
          1 1 0 0 1 1 1 2 0 0 0 0 0 0
        INPUT
      end

      it "returns a command to empty hand to then proceed to chop wars" do
        is_expected.to eq("MSG *cracks neck*; DROP 0")
      end
    end

    context "with seed=-5675974997497346000, wide open fields, far iron" do
      let(:field) do
        <<~FIELD
          .........1..........~.
          ~~~~.............#..~.
          ..~~................~.
          ..~+................~.
          ......................
          ...+..............+...
          ......................
          .~................+~..
          .~................~~..
          .~..#.............~~~~
          .~..........0.........
        FIELD
      end

      context "when just trained inter and should decide on chopper quality" do
        let(:turn) { 2 }

        let(:input) do
          <<~INPUT
            0 1 4 7 0 0
            5 6 9 7 2 0
            16
            PLUM 20 8 4 12 1 1
            PLUM 1 2 4 12 1 1
            PLUM 14 1 4 12 2 4
            PLUM 7 9 4 12 2 4
            LEMON 11 6 4 12 3 3
            LEMON 10 4 4 12 3 3
            APPLE 0 7 4 20 1 1
            APPLE 21 3 4 20 1 1
            APPLE 8 8 4 20 0 5
            APPLE 13 2 4 20 0 5
            APPLE 0 8 3 17 0 1
            APPLE 21 2 3 17 0 1
            BANANA 8 4 1 3 0 5
            BANANA 13 6 1 3 0 5
            BANANA 11 3 4 6 3 3
            BANANA 10 7 4 6 3 3
            3
            0 1 10 0 1 1 1 1 0 0 0 0 0 0
            1 0 12 9 1 1 1 1 0 0 0 0 0 0
            2 0 12 10 2 2 2 1 0 0 0 0 0 0
          INPUT
        end

        # In reality I get to chopper no later than by turn 153, so by two workers scaling takes 152 turns or so + inefficiencies
        # Predictive algo says 204 turns :/
        it "returns a command to continue mining cuz bag not full" do
          is_expected.to eq("MSG getting seed PLUM; PICK 1 LEMON; MOVE 2 11 9")
        end
      end

      context "when just trained inter and should decide on chopper quality (prefer cheapest scenario)" do
        let(:turn) { 113 }

        let(:input) do
          <<~INPUT
            6 11 4 1 11 0
            5 6 9 7 2 0
            4
            BANANA 8 4 1 3 0 5
            BANANA 13 6 1 3 0 5
            BANANA 11 3 4 6 3 3
            BANANA 10 7 4 6 3 3
            3
            0 1 10 0 1 1 1 1 0 0 0 0 0 0
            1 0 12 9 1 1 1 1 0 0 0 0 0 0
            2 0 12 10 2 2 2 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to train -1carry chopper, which is determined to be best at this juncture" do
          is_expected.to match("TRAIN 2 3 0 3")
        end
      end

      context "when mining last iron for chopper" do
        let(:turn) { 108 }

        let(:input) do
          <<~INPUT
            7 18 4 7 4 0
            6 16 8 15 1 0
            21
            PLUM 20 8 4 12 3 0
            PLUM 1 2 4 12 3 0
            PLUM 14 1 4 12 3 0
            PLUM 7 9 4 12 3 0
            LEMON 11 6 4 12 3 0
            LEMON 10 4 4 12 3 4
            APPLE 0 7 4 20 3 0
            APPLE 21 3 4 20 3 0
            APPLE 8 8 4 20 3 0
            APPLE 13 2 4 20 3 0
            APPLE 0 8 4 20 3 0
            APPLE 21 2 4 20 3 0
            BANANA 8 4 4 6 3 0
            BANANA 13 6 4 6 3 0
            BANANA 11 3 4 6 3 0
            BANANA 10 7 4 6 3 0
            LEMON 12 9 4 12 3 0
            PLUM 10 9 4 12 3 0
            LEMON 9 1 4 12 3 7
            LEMON 12 8 4 12 3 0
            PLUM 10 0 4 12 3 5
            4
            0 1 9 1 1 1 1 1 0 1 0 0 0 0
            1 0 16 7 1 1 1 1 0 0 0 0 0 0
            2 0 17 7 2 2 2 1 0 0 0 0 1 0
            3 1 9 2 1 1 1 0 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to continue mining cuz bag not full" do
          is_expected.to eq("MSG IROON!; MOVE 1 17 7; MINE 2")
        end
      end
    end

    context "with seed=3105322776010436000" do
      let(:field) do
        <<~FIELD
          ......1.....#~~~~...
          ............~~..~...
          .........+#.....~...
          ...#..##............
          ....................
          ....................
          ............##..#...
          ...~.....#+.........
          ...~..~~............
          ...~~~~#.....0......
        FIELD
      end

      context "when fiels is wide open and paths are likely inefficient" do
        let(:input) do
          <<~INPUT
            1 8 4 5 6 0
            1 1 0 4 7 0
            25
            PLUM 14 1 4 12 3 0
            PLUM 5 8 4 12 3 0
            PLUM 19 2 4 12 3 0
            PLUM 0 7 4 12 3 0
            LEMON 18 0 4 12 3 0
            LEMON 1 9 4 12 3 0
            LEMON 15 6 4 12 3 7
            LEMON 4 3 4 12 3 0
            APPLE 0 4 4 20 3 0
            APPLE 19 5 4 20 3 0
            APPLE 5 3 4 20 1 8
            APPLE 14 6 4 20 3 0
            BANANA 5 7 4 6 3 0
            BANANA 14 2 4 6 3 0
            BANANA 5 4 4 6 3 0
            BANANA 14 5 4 6 3 0
            LEMON 13 8 4 12 1 8
            LEMON 13 7 4 12 0 3
            PLUM 14 7 4 12 0 6
            PLUM 5 0 4 12 1 1
            LEMON 7 0 4 12 1 5
            APPLE 6 1 4 20 0 4
            BANANA 4 0 4 6 1 1
            APPLE 5 1 1 11 0 1
            APPLE 6 2 1 11 0 5
            4
            0 1 7 1 1 1 1 1 0 0 1 0 0 0
            1 0 13 8 1 1 1 1 0 0 0 0 0 0
            2 1 8 0 3 1 2 2 0 0 1 0 0 0
            3 0 14 7 3 1 1 1 1 0 0 0 0 0
          INPUT
        end

        it "returns command quickly" do
          is_expected.to eq("MSG oh LEMON; HARVEST 1; MOVE 3 13 8")
        end
      end
    end

    context "with seed=-2870672166963997000" do
      let(:field) do
        <<~FIELD
          ~#...~...........~~~
          ~~...~.#..#.....~~~~
          ....#~~......1...~~.
          ........#........~~.
          ..~.......+......~~.
          .~~......+.......~..
          .~~........#........
          .~~...0......~~#....
          ~~~~.....#..#.~...~~
          ~~~...........~...#~
        FIELD
      end

      context "when I have everything for a TRAIN 2 3 0 3, but it would be better to just gather lemons" do
        let(:turn) { 47 }
        let(:input) do
          <<~INPUT
            7 10 7 5 10 0
            6 4 4 5 6 0
            20
            PLUM 14 2 4 12 1 2
            PLUM 5 7 4 12 3 0
            LEMON 17 6 4 12 3 0
            LEMON 2 3 4 12 3 0
            LEMON 15 6 4 12 2 6
            LEMON 4 3 4 12 3 0
            APPLE 18 7 4 20 3 0
            APPLE 1 2 4 20 3 0
            BANANA 14 4 4 6 3 0
            BANANA 5 5 4 6 3 0
            BANANA 8 6 4 6 3 0
            BANANA 11 3 4 6 3 0
            APPLE 13 3 4 20 1 1
            LEMON 3 7 4 12 3 0
            LEMON 12 2 4 12 1 8
            LEMON 13 1 4 12 0 4
            LEMON 14 1 4 12 1 7
            PLUM 15 2 4 12 0 3
            LEMON 14 3 3 10 0 5
            LEMON 12 3 2 8 0 1
            3
            0 0 6 6 1 1 1 1 0 0 0 0 0 0
            1 1 14 2 1 1 1 1 0 0 0 0 0 0
            2 1 15 4 2 2 1 1 0 2 0 0 0 0
          INPUT
        end

        it "returns a command to just continue harvesting lemons for a better chopper" do
          is_expected.to eq("MSG trns till LEMON 5; MOVE 0 5 6")
          expect(controller.send(:turns_to_gather, "LEMON", 7)).to eq(42)
        end
      end
    end

    context "with seed=4799495527170431000 | Testing race to the bottom against WeepingAngel89" do
      let(:field) do
        <<~FIELD
          .....1.......~..
          ~~.....#..#..~..
          ..#....#........
          ........+#...##.
          .##...#+........
          ........#....#..
          ..~..#..#.....~~
          ..~.......0.....
        FIELD
      end

      context "when situation is such that getting lemons off the ground is unrealistic" do
        let(:turn) { 2 }

        let(:input) do
          <<~INPUT
            3 0 3 6 2 0
            3 0 3 6 2 0
            10
            PLUM 1 3 2 8 0 8
            PLUM 14 4 2 8 0 8
            LEMON 11 2 1 6 0 4
            LEMON 4 5 1 6 0 4
            APPLE 9 2 2 14 0 8
            APPLE 6 5 2 14 0 8
            APPLE 2 3 4 20 3 2
            APPLE 13 4 4 20 3 2
            BANANA 12 6 1 3 0 2
            BANANA 3 1 1 3 0 2
            4
            0 1 6 0 1 1 1 1 0 0 0 0 0 0
            1 0 10 6 1 1 1 1 0 0 0 0 0 0
            2 1 5 0 2 2 2 2 0 0 0 0 0 0
            3 0 10 7 2 2 2 2 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to self-harvest bananas in my corner of map" do
          # is_expected.to eq("MSG race to bottom; PICK 1 BANANA; MOVE 3 11 6")
          is_expected.to eq("MSG race to bottom; MOVE 1 11 6; MOVE 3 11 6")
          expect(controller.send(:turns_till_own_lemon_tree)).to eq(65)
        end
      end

      context "when situation is such that getting lemons off the ground is unrealistic" do
        let(:turn) { 17 }

        let(:input) do
          <<~INPUT
            3 0 3 3 2 2
            3 0 2 6 2 0
            10
            PLUM 1 3 3 10 0 1
            PLUM 14 4 3 10 0 1
            LEMON 11 2 3 10 0 5
            LEMON 4 5 3 10 0 5
            APPLE 6 5 3 17 0 2
            APPLE 2 3 4 20 3 0
            APPLE 13 4 4 20 3 0
            BANANA 12 6 4 6 0 5
            APPLE 6 1 2 2 0 6
            BANANA 10 6 1 2 0 5
            4
            0 1 6 1 1 1 1 1 0 0 0 0 0 0
            1 0 10 6 1 1 1 1 0 0 0 0 0 0
            2 1 6 0 2 2 2 2 0 0 0 0 0 2
            3 0 7 7 2 2 2 2 0 0 0 0 0 2
          INPUT
        end

        it "returns a command to continue chopping for self-harvest banana" do
          is_expected.to eq("CHOP 1; MOVE 3 9 7")
          # expect(controller.send(:turns_till_own_lemon_tree)).to eq(65)
        end
      end

      context "when helper is self-seeding a plum" do
        let(:turn) { 44 }

        let(:input) do
          <<~INPUT
            2 0 3 0 2 12
            3 0 0 6 2 6
            8
            PLUM 1 3 4 12 3 6
            LEMON 4 5 4 12 2 2
            APPLE 6 5 4 20 2 2
            APPLE 2 3 4 20 3 0
            APPLE 13 4 4 20 3 0
            BANANA 12 6 4 6 3 0
            PLUM 11 7 1 4 0 6
            APPLE 4 1 1 10 0 8
            4
            0 1 4 1 1 1 1 1 0 0 0 0 0 0
            1 0 11 7 1 1 1 1 0 0 0 0 0 0
            2 1 10 0 2 2 2 2 0 0 0 0 0 2
            3 0 10 6 2 2 2 2 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for inter not to desire it, got to nearby banana instead" do
          is_expected.to eq("MSG race to bottom; CHOP 1; MOVE 3 12 6")
        end
      end
    end

    context "with seed=" do
      let(:field) do
        <<~FIELD
          ..............~~~~~.
          .......1......~~~~..
          ............+~~~~~..
          .............~~~....
          .#....#......~~~~...
          ...~~~~......#....#.
          ....~~~.............
          ..~~~~~+............
          ..~~~~......0.......
          .~~~~~..............
        FIELD
      end

      context "when there's plenty of space to the right, away from opp" do
        let(:input) do
          <<~INPUT
            5 8 6 3 5 0
            5 8 6 3 5 0
            20
            PLUM 7 2 2 8 0 2
            PLUM 12 7 2 8 0 2
            PLUM 7 3 4 12 3 2
            PLUM 12 6 4 12 3 2
            PLUM 4 4 4 12 3 3
            PLUM 15 5 4 12 3 3
            LEMON 17 6 4 12 1 6
            LEMON 2 3 4 12 1 6
            LEMON 16 3 3 10 0 2
            LEMON 3 6 3 10 0 2
            APPLE 16 5 2 14 0 2
            APPLE 3 4 2 14 0 2
            APPLE 19 3 4 20 1 5
            APPLE 0 6 4 20 1 5
            APPLE 19 5 4 20 0 2
            APPLE 0 4 4 20 0 2
            BANANA 19 1 3 5 0 5
            BANANA 0 8 3 5 0 5
            BANANA 6 8 4 6 1 3
            BANANA 13 1 4 6 1 3
            2
            0 1 7 1 1 1 1 1 0 0 0 0 0 0
            1 0 12 8 1 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to lemon to the right, away from opp on" do
          is_expected.to contain("MSG trns till LEMON 8; MOVE 1 12 7")
        end
      end

      context "when it's premiere endgame and it's time to self-plant aggressively" do
        let(:input) do
          <<~INPUT
            7 9 10 2 2 35
            8 2 1 0 0 38
            0
            6
            0 1 8 1 1 1 1 1 0 0 0 0 0 0
            1 0 12 6 1 1 1 1 0 0 0 0 0 0
            2 1 9 1 2 2 2 2 0 0 0 0 0 2
            3 0 12 7 2 2 2 2 0 0 0 0 0 0
            4 1 7 2 2 2 2 2 0 0 0 0 0 1
            5 0 9 2 2 4 0 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for chopper to harass enemy camp while inter and helper self-plant" do
          is_expected.to eq("MSG hugging opp; MOVE 5 8 1; MOVE 1 13 6; MOVE 3 13 8")
        end
      end

      context "when it's premiere endgame and it's time to self-plant aggressively" do
        let(:turn) { 226 }
        let(:input) do
          <<~INPUT
            5 9 10 0 2 38
            4 2 1 0 0 43
            1
            PLUM 8 1 1 6 0 8
            6
            0 1 8 3 1 1 1 1 0 0 0 0 0 0
            1 0 13 8 1 1 1 1 1 0 0 0 0 0
            2 1 8 1 2 2 2 2 0 0 0 0 0 0
            3 0 12 9 2 2 2 2 0 0 0 0 0 0
            4 1 7 2 2 2 2 2 1 0 0 0 0 0
            5 0 11 2 2 4 0 3 0 0 0 0 0 2
          INPUT
        end

        it "returns a command for chopper and inter to harass enemy camp while helper self-plants" do
          is_expected.to eq("MSG slim pickings; MOVE 5 9 2; PLANT 1 PLUM; MOVE 3 11 8")
        end
      end

      context "when it's premiere endgame and it's time to self-plant aggressively, and helper is already taking up one of the two spots" do
        let(:turn) { 271 }
        let(:input) do
          <<~INPUT
            0 6 10 0 2 49
            0 0 0 0 0 54
            0
            6
            0 1 7 5 1 1 1 1 0 0 0 0 0 0
            1 0 13 8 1 1 1 1 0 0 0 0 0 1
            2 1 8 1 2 2 2 2 0 0 0 0 0 0
            3 0 12 9 2 2 2 2 0 1 0 0 0 0
            4 1 5 0 2 2 2 2 0 0 0 0 0 0
            5 0 13 6 2 4 0 3 0 0 0 0 0 2
          INPUT
        end

        it "returns a command for inter to stay on the alterante best my-side self node hes already on" do
          is_expected.to eq("MSG hugging opp; MOVE 5 12 5; DROP 1; PLANT 3 LEMON")
        end
      end
    end

    context "with SYNTHETIC SETUP for a banana that will grow next turn to size 4 and its ok to start chopping it already" do
      let(:field) do
        <<~FIELD
          ......~~....##.+
          ..1.~~~~..#.#..#
          #....~...#.....#
          ~.............~~
          ~~.............~
          #.....#...~....#
          #..#.#..~~~~.0..
          +.##....~~......
        FIELD
      end

      context "when " do
        let(:input) do
          <<~INPUT
            0 1 11 1 0 8
            0 0 3 5 3 0
            15
            LEMON 7 2 4 12 3 0
            LEMON 8 5 4 12 3 0
            LEMON 7 5 4 12 3 0
            LEMON 8 2 4 12 3 0
            BANANA 9 4 4 6 3 0
            BANANA 6 3 4 6 3 0
            LEMON 2 0 4 12 3 0
            PLUM 3 0 4 12 3 0
            LEMON 5 3 4 12 3 0
            PLUM 4 3 4 12 3 0
            LEMON 3 3 4 12 3 0
            BANANA 13 5 3 5 0 1
            BANANA 13 4 4 6 0 0
            BANANA 14 5 2 4 0 5
            BANANA 14 4 2 4 0 3
            6
            0 1 3 3 1 1 1 1 0 0 0 0 0 0
            1 0 13 4 1 1 1 1 0 0 0 0 0 0
            2 1 3 1 2 1 2 1 0 0 0 0 0 0
            3 0 12 6 2 1 1 1 0 0 0 0 0 0
            4 0 13 5 2 4 0 2 0 0 0 0 0 0
            5 1 2 2 2 3 1 2 0 0 0 0 3 0
          INPUT
        end

        it "returns a command to chop the banana already on" do
          is_expected.to eq("MSG hee hee; CHOP 4; MOVE 1 13 5; MOVE 3 12 4")
        end
      end
    end

    context "with seed=-8264371801288317000 | interesting one-cell bridge map" do
      let(:field) do
        <<~FIELD
          .........+....~.......
          .......~...1..~~~.....
          .#..~~~~.....~~~~.....
          ..+..~~~~...~~~~~.....
          ......~~~~.~~~~~......
          .......~~~..~~~.......
          ......~~~~~.~~~~......
          .....~~~~~...~~~~..+..
          .....~~~~.....~~~~..#.
          .....~~~..0...~.......
          .......~....+.........
        FIELD
      end

      context "when interesting one-cell bridge map" do
        let(:input) do
          <<~INPUT
            8 5 9 6 8 0
            8 5 9 6 8 0
            16
            PLUM 0 5 2 8 0 2
            PLUM 21 5 2 8 0 2
            PLUM 8 0 4 12 1 2
            PLUM 13 10 4 12 1 2
            PLUM 19 2 3 10 0 2
            PLUM 2 8 3 10 0 2
            LEMON 1 6 4 12 0 8
            LEMON 20 4 4 12 0 8
            LEMON 9 10 1 6 0 1
            LEMON 12 0 1 6 0 1
            APPLE 19 9 4 20 0 3
            APPLE 2 1 4 20 0 3
            BANANA 0 7 1 3 0 5
            BANANA 21 3 1 3 0 5
            BANANA 20 7 4 6 0 2
            BANANA 1 3 4 6 0 2
            2
            0 0 10 9 1 1 1 1 0 0 0 0 0 0
            1 1 11 1 1 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "inits seed node correctly to tucked-away 8 9" do
          subject
          # is_expected.to eq("TODO")
          expect(controller.send(:seed_node)).to eq("8 9")
        end
      end
    end

    context "with seed=4316117710575937500 | Interesting base choke and best to build behind it" do
      let(:field) do
        <<~FIELD
          ..+...........+.....
          ..........#..0..~...
          ....~~.~~~....~~~~..
          ...~~~~~~..~~~~~~~..
          ..~~~~~~~..~~~~~~~..
          ..~~~~~~~..~~~~~~~..
          ..~~~~~~~..~~~~~~...
          ..~~~~....~~~.~~....
          ...~..1..#..........
          .....+...........+..
        FIELD
      end

      context "when just starting" do
        let(:input) do
          <<~INPUT
            5 6 9 5 6 0
            5 6 9 5 6 0
            16
            PLUM 19 3 4 12 0 8
            PLUM 0 6 4 12 0 8
            PLUM 5 8 4 12 1 3
            PLUM 14 1 4 12 1 3
            LEMON 10 9 4 12 0 1
            LEMON 9 0 4 12 0 1
            LEMON 0 9 4 12 3 5
            LEMON 19 0 4 12 3 5
            LEMON 17 8 4 12 1 8
            LEMON 2 1 4 12 1 8
            APPLE 15 8 4 20 0 2
            APPLE 4 1 4 20 0 2
            BANANA 18 4 4 6 0 4
            BANANA 1 5 4 6 0 4
            BANANA 15 9 4 6 2 2
            BANANA 4 0 4 6 2 2
            2
            0 1 6 8 1 1 1 1 0 0 0 0 0 0
            1 0 13 1 1 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to move to the right, the secluded side of camp" do
          is_expected.to eq("MOVE 1 14 1")
          expect(controller.send(:seed_node)).to eq("15 1")
        end
      end
    end

    context "with seed=-2046562276680836000 | sidewater" do
      let(:field) do
        <<~FIELD
          ...............~
          ~.+............~
          ~~~............~
          ~~..0#........~~
          ~~........#1..~~
          ~............~~~
          ~............+.~
          ~...............
        FIELD
      end

      context "when chopper just dropped wood and there are several options around" do
        let(:turn) { 83 }
        let(:input) do
          <<~INPUT
            6 2 0 1 0 8
            0 0 9 5 1 6
            17
            PLUM 12 7 4 8 2 3
            PLUM 3 0 4 12 3 0
            LEMON 1 1 4 12 3 0
            LEMON 14 6 4 12 3 0
            LEMON 11 3 4 12 3 5
            LEMON 4 4 4 12 3 0
            LEMON 1 7 4 12 3 0
            LEMON 14 0 4 12 3 0
            APPLE 14 7 4 20 3 0
            APPLE 1 0 4 20 3 0
            APPLE 11 5 4 20 3 9
            PLUM 2 3 4 12 3 3
            BANANA 5 2 3 5 0 6
            BANANA 3 2 3 5 0 4
            BANANA 3 3 1 3 0 2
            BANANA 3 4 1 3 0 5
            LEMON 13 3 1 6 0 3
            6
            0 0 3 3 1 1 1 1 0 0 0 0 0 0
            1 1 13 3 1 1 1 1 0 0 0 0 0 0
            2 0 2 3 1 2 2 1 0 0 0 0 0 0
            3 1 12 7 2 2 1 2 0 0 0 0 0 0
            4 0 4 2 2 4 0 3 0 0 0 0 0 0
            5 1 11 3 2 2 1 2 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for chopper to get closer to nearby busy plumtree chopping, pushing Inter out of the way" do
          is_expected.to eq("MSG sidestepping; MOVE 4 3 3; MOVE 0 2 3; MOVE 2 2 4")
        end
      end
    end

    context "with seed=" do
      let(:field) do
        <<~FIELD
          .......~~~~~~~~.....
          .....#.~~~~~~~~~....
          ....#...+~~~~~~~....
          .........~~~#~~~....
          .....0.....+#.......
          .......#+.....1.....
          ....~~~#~~~.........
          ....~~~~~~~+...#....
          ....~~~~~~~~~.#.....
          .....~~~~~~~~.......
        FIELD
      end

      context "when planting tons of bananas" do
        let(:turn) { 118 }
        let(:input) do
          <<~INPUT
            1 0 9 2 0 16
            4 16 0 8 11 0
            27
            PLUM 19 8 4 12 3 0
            PLUM 0 1 4 12 3 0
            PLUM 17 0 4 12 3 0
            PLUM 2 9 4 12 3 0
            LEMON 9 4 4 12 3 0
            LEMON 10 5 4 12 3 0
            LEMON 3 2 4 12 3 0
            LEMON 16 7 4 12 3 0
            LEMON 0 5 4 12 3 0
            LEMON 19 4 4 12 3 0
            APPLE 13 4 4 20 3 0
            APPLE 6 5 4 20 3 2
            APPLE 1 2 4 20 3 0
            APPLE 18 7 4 20 3 0
            BANANA 15 5 4 6 3 0
            BANANA 3 0 4 6 3 0
            BANANA 16 9 4 6 3 0
            PLUM 13 5 4 12 0 5
            PLUM 12 5 4 12 2 8
            LEMON 13 6 4 12 2 5
            LEMON 14 6 4 12 1 7
            LEMON 15 6 4 12 3 0
            LEMON 14 4 4 12 2 1
            BANANA 5 3 4 6 0 6
            BANANA 4 5 3 5 0 4
            BANANA 4 4 1 3 0 1
            BANANA 5 5 1 3 0 3
            6
            0 0 5 5 1 1 1 1 0 0 0 1 0 0
            1 1 13 5 1 1 1 1 0 0 0 0 0 0
            2 0 6 5 1 2 2 2 0 0 2 0 0 0
            3 1 12 5 2 2 2 0 2 0 0 0 0 0
            4 1 9 5 3 4 1 2 0 1 0 0 3 0
            5 0 6 4 2 4 0 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for helper to go left, in secure area to plant banana" do
          is_expected.to eq("MOVE 5 5 3; MOVE 0 4 5; MOVE 2 5 5")
        end
      end
    end

    context "with seed=" do
      let(:field) do
        <<~FIELD
          ...................#
          .............+.....~
          ...........1...~~.~~
          ..~~~.~.....~~~~~~~~
          ..~~~.~.....~~~~~~..
          ..~~~~~~.....~.~~~..
          ~~~~~~~~.....~.~~~..
          ~~.~~...0...........
          ~.....+.............
          #...................
        FIELD
      end

      context "when " do
        let(:turn) { 20 }
        let(:input) do
          <<~INPUT
            6 10 4 3 6 0
            2 4 3 3 4 2
            18
            PLUM 14 7 4 12 3 2
            PLUM 5 2 4 12 2 2
            LEMON 9 1 4 12 3 0
            LEMON 10 8 4 12 2 7
            LEMON 19 5 3 10 0 3
            LEMON 0 4 3 10 0 3
            APPLE 12 7 4 20 1 9
            APPLE 7 2 4 20 1 9
            APPLE 12 8 4 20 3 0
            APPLE 7 1 4 20 3 0
            APPLE 10 2 4 20 0 7
            APPLE 9 7 4 20 0 7
            BANANA 1 3 4 6 3 0
            BANANA 18 6 4 6 3 0
            BANANA 12 5 4 6 3 0
            BANANA 15 1 4 6 3 0
            BANANA 4 8 4 6 3 0
            LEMON 8 6 4 9 1 1
            3
            0 0 8 6 1 1 1 1 0 1 0 0 0 0
            1 1 6 2 1 1 1 1 0 0 0 0 0 0
            2 1 8 6 2 2 0 1 0 0 0 0 0 0
          INPUT
        end

        it "returns to drop lemon in hand for chop battle" do
          is_expected.to eq("DROP 0")
        end
      end
    end

    context "with seed=" do
      let(:field) do
        <<~FIELD
          .......#..1..~........
          ..+.........~~........
          ..#.#.......~~~~.+....
          ~~~#......#...~.......
          ~~~~~.............~..~
          ~~~~..............~~~~
          ~..~.............~~~~~
          .......~...#......#~~~
          ....+.~~~~.......#.#..
          ........~~.........+..
          ........~..0..#.......
        FIELD
      end

      context "when both helper and inter want the same node" do
        let(:turn) { 25 }
        let(:input) do
          <<~INPUT
            4 4 4 5 2 0
            0 2 8 5 2 0
            22
            PLUM 10 2 4 12 2 2
            PLUM 1 9 4 12 1 4
            PLUM 20 1 4 12 1 4
            LEMON 9 2 4 12 3 0
            LEMON 12 8 4 7 1 7
            LEMON 16 7 4 12 1 3
            LEMON 5 3 4 12 1 3
            LEMON 4 0 4 12 0 5
            LEMON 17 10 4 12 0 5
            APPLE 19 1 4 20 1 8
            APPLE 2 9 4 20 1 8
            APPLE 5 1 4 20 3 2
            APPLE 16 9 4 20 3 2
            APPLE 9 1 4 20 3 0
            APPLE 12 9 4 20 3 0
            BANANA 7 9 4 6 3 0
            BANANA 14 1 4 6 3 0
            BANANA 5 9 4 6 3 0
            BANANA 16 1 4 6 3 0
            BANANA 1 6 4 6 3 4
            BANANA 20 4 4 6 3 4
            LEMON 10 9 4 12 1 1
            4
            0 1 12 8 1 1 1 1 0 0 0 0 0 0
            1 0 10 9 1 1 1 1 0 1 0 0 0 0
            2 0 10 10 1 2 2 2 0 2 0 0 0 0
            3 1 9 6 2 2 0 2 0 0 0 0 0 2
          INPUT
        end

        it "returns a command for inter to scurry off" do
          is_expected.to eq("MSG sidestepping; MOVE 1 10 10; MOVE 2 10 9")
        end
      end

      context "when helper will pick and inter should just go to other nearby free dropoff" do
        let(:turn) { 26 }
        let(:input) do
          <<~INPUT
            4 4 4 5 2 0
            0 2 8 5 2 0
            22
            PLUM 10 2 4 12 2 1
            PLUM 1 9 4 12 1 3
            PLUM 20 1 4 12 1 3
            LEMON 9 2 4 12 3 0
            LEMON 12 8 4 6 1 6
            LEMON 16 7 4 12 1 2
            LEMON 5 3 4 12 1 2
            LEMON 4 0 4 12 0 4
            LEMON 17 10 4 12 0 4
            APPLE 19 1 4 20 1 7
            APPLE 2 9 4 20 1 7
            APPLE 5 1 4 20 3 1
            APPLE 16 9 4 20 3 1
            APPLE 9 1 4 20 3 0
            APPLE 12 9 4 20 3 0
            BANANA 7 9 4 6 3 0
            BANANA 14 1 4 6 3 0
            BANANA 5 9 4 6 3 0
            BANANA 16 1 4 6 3 0
            BANANA 1 6 4 6 3 3
            BANANA 20 4 4 6 3 3
            LEMON 10 9 4 12 2 3
            4
            0 1 12 8 1 1 1 1 0 0 0 0 0 0
            1 0 10 10 1 1 1 1 0 1 0 0 0 0
            2 0 10 9 1 2 2 2 0 2 0 0 0 0
            3 1 9 4 2 2 0 2 0 0 0 0 0 2
          INPUT
        end

        it "returns a command for inter to got to free dropoff" do
          is_expected.to include("MOVE 2 11 9")
        end
      end
    end

    context "with seed=" do
      let(:field) do
        <<~FIELD
          ..+..#......#~~~
          .......#.#.~~~~~
          .....#.....~~~~~
          +.....1....~~...
          ...~~....0.....+
          ~~~~~.....#.....
          ~~~~~.#.#.......
          ~~~#......#..+..
        FIELD
      end

      context "when its the very 1st turn and we're getting an intern" do
        let(:turn) { 1 }
        let(:input) do
          <<~INPUT
            9 2 6 6 4 0
            9 2 6 6 4 0
            18
            PLUM 14 6 4 12 1 8
            PLUM 1 1 4 12 1 8
            PLUM 10 4 4 12 1 7
            PLUM 5 3 4 12 1 7
            LEMON 0 2 3 10 0 2
            LEMON 15 5 3 10 0 2
            LEMON 9 0 2 8 0 3
            LEMON 6 7 2 8 0 3
            APPLE 12 7 3 17 0 5
            APPLE 3 0 3 17 0 5
            APPLE 4 0 4 20 0 2
            APPLE 11 7 4 20 0 2
            APPLE 8 1 4 20 1 9
            APPLE 7 6 4 20 1 9
            BANANA 9 6 4 6 0 6
            BANANA 6 1 4 6 0 6
            BANANA 4 2 4 6 2 1
            BANANA 11 5 4 6 2 1
            2
            0 1 6 3 1 1 1 1 0 0 0 0 0 0
            1 0 9 4 1 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for helper to go right, away from opp" do
          is_expected.to eq("TRAIN 2 1 1 1; MOVE 1 10 4")
        end
      end

      context "when inter is carrying a lemon near opp base which happens to be closest 3-cell to base" do
        let(:turn) { 2 }
        let(:input) do
          <<~INPUT
            4 0 4 6 2 0
            9 2 6 6 4 0
            18
            PLUM 14 6 4 12 1 7
            PLUM 1 1 4 12 1 7
            PLUM 10 4 4 12 1 6
            PLUM 5 3 4 12 1 6
            LEMON 0 2 3 10 0 1
            LEMON 15 5 3 10 0 1
            LEMON 9 0 2 8 0 2
            LEMON 6 7 2 8 0 2
            APPLE 12 7 3 17 0 4
            APPLE 3 0 3 17 0 4
            APPLE 4 0 4 20 0 1
            APPLE 11 7 4 20 0 1
            APPLE 8 1 4 20 1 8
            APPLE 7 6 4 20 1 8
            BANANA 9 6 4 6 0 5
            BANANA 6 1 4 6 0 5
            BANANA 4 2 4 6 3 6
            BANANA 11 5 4 6 3 6
            3
            0 1 5 3 1 1 1 1 0 0 0 0 0 0
            1 0 9 3 1 1 1 1 0 0 0 0 0 0
            2 0 9 4 2 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for inter not to plant, but get closer home" do
          is_expected.to eq("MSG trns till PLUM 3, getting seed LEMON; MOVE 1 10 3; MOVE 2 11 4")
        end
      end

      context "when inter is carrying a lemon near opp base which happens to be closest 3-cell to base" do
        let(:turn) { 15 }
        let(:input) do
          <<~INPUT
            6 0 4 6 2 0
            9 2 6 6 5 0
            18
            PLUM 14 6 4 12 2 1
            PLUM 1 1 4 12 2 1
            PLUM 10 4 4 12 1 8
            PLUM 5 3 4 12 3 8
            LEMON 0 2 4 12 0 3
            LEMON 15 5 4 12 1 3
            LEMON 9 0 4 12 0 4
            LEMON 6 7 4 12 0 4
            APPLE 12 7 4 20 1 8
            APPLE 3 0 4 20 1 8
            APPLE 4 0 4 20 2 5
            APPLE 11 7 4 20 2 5
            APPLE 8 1 4 20 2 3
            APPLE 7 6 4 20 2 3
            BANANA 9 6 4 6 2 3
            BANANA 6 1 4 6 2 3
            BANANA 4 2 4 6 3 0
            BANANA 11 5 4 6 3 0
            3
            0 1 8 4 1 1 1 1 0 0 0 0 0 0
            1 0 13 4 1 1 1 1 0 0 0 0 1 0
            2 0 6 4 2 1 1 1 0 1 0 0 0 0
          INPUT
        end

        it "returns a command for inter not to plant, but get closer home" do
          is_expected.to include("MOVE 2 7 5")
        end
      end

      context "when " do
        let(:turn) { 28 }
        let(:input) do
          <<~INPUT
            6 1 4 6 4 0
            9 3 6 6 5 0
            19
            PLUM 14 6 4 12 3 0
            PLUM 1 1 4 12 3 0
            PLUM 10 4 4 12 2 2
            PLUM 5 3 4 12 3 0
            LEMON 0 2 4 12 1 5
            LEMON 15 5 4 12 3 5
            LEMON 9 0 4 12 2 6
            LEMON 6 7 4 12 1 6
            APPLE 12 7 4 20 2 3
            APPLE 3 0 4 20 2 3
            APPLE 4 0 4 20 3 0
            APPLE 11 7 4 20 3 0
            APPLE 8 1 4 20 3 0
            APPLE 7 6 4 20 3 0
            BANANA 9 6 4 6 3 0
            BANANA 6 1 4 6 3 0
            BANANA 4 2 4 6 3 0
            BANANA 11 5 4 6 3 0
            LEMON 6 4 2 8 0 3
            3
            0 1 5 3 1 1 1 1 0 0 0 0 0 0
            1 0 10 4 1 1 1 1 0 0 0 0 0 0
            2 0 10 6 2 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for helper to scale some lemons, goddamit" do
          is_expected.to include("PICK 1 LEMON")
        end
      end
    end

    context "with seed=-3167202023676340000 | nasing spešel field with some dry lemons" do
      let(:field) do
        <<~FIELD
          ~~..............
          ~~.........+....
          ~~~.1...........
          ..~~..#..#....#.
          .#....#..#..~~..
          ...........0.~~~
          ....+.........~~
          ..............~~
        FIELD
      end

      context "when chopper just spawned" do
        let(:turn) { 77 }
        let(:input) do
          <<~INPUT
            1 2 1 7 1 0
            8 6 7 7 5 0
            19
            PLUM 4 7 4 12 3 0
            PLUM 11 0 4 12 3 0
            LEMON 10 5 4 12 2 7
            LEMON 5 2 4 12 0 1
            LEMON 13 0 4 12 3 0
            LEMON 2 7 4 12 3 0
            LEMON 4 5 4 12 3 0
            LEMON 11 2 4 12 3 0
            APPLE 7 7 4 20 3 0
            APPLE 8 0 4 20 3 0
            BANANA 11 4 4 6 3 0
            BANANA 4 3 4 6 3 0
            BANANA 7 4 4 6 3 0
            BANANA 8 3 4 6 3 0
            PLUM 4 1 4 12 0 1
            PLUM 4 4 4 12 1 1
            PLUM 12 5 4 12 3 0
            APPLE 3 2 4 20 3 0
            APPLE 3 1 4 20 1 1
            6
            0 1 4 5 1 1 1 1 0 0 0 0 1 0
            1 0 11 4 1 1 1 1 0 0 0 0 0 0
            2 1 5 6 1 1 1 1 0 0 0 0 1 0
            3 0 10 5 2 2 2 2 0 2 0 0 0 0
            4 1 4 4 2 2 2 2 0 0 0 0 0 0
            5 0 11 5 2 4 0 3 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for inter to sidestep to an empty square to drop" do
          is_expected.to eq("MSG beeline, sidestepping; MOVE 5 10 5; HARVEST 1; MOVE 3 11 6")
        end
      end

      context "when inter has wondered off to previously gather" do
        let(:turn) { 96 }
        let(:input) do
          <<~INPUT
            5 4 1 7 1 8
            1 5 0 11 2 4
            16
            PLUM 4 7 4 12 3 0
            PLUM 11 0 4 12 3 0
            LEMON 5 2 4 12 0 5
            LEMON 13 0 4 12 3 0
            LEMON 2 7 4 12 3 0
            LEMON 4 5 4 12 2 3
            APPLE 7 7 4 20 3 0
            APPLE 8 0 4 20 3 0
            BANANA 11 4 4 6 3 3
            BANANA 8 3 4 6 3 0
            PLUM 4 1 4 12 3 5
            PLUM 4 4 4 12 2 7
            PLUM 12 5 4 12 2 3
            APPLE 3 2 4 20 3 0
            APPLE 3 1 4 20 3 0
            BANANA 11 3 3 5 0 1
            7
            0 1 4 4 1 1 1 1 0 0 0 0 0 0
            1 0 10 4 1 1 1 1 0 0 0 1 0 0
            2 1 10 3 1 1 1 1 0 0 0 0 0 1
            3 0 7 6 2 2 2 2 0 0 0 0 0 0
            4 1 4 3 2 2 2 2 2 0 0 0 0 0
            5 0 10 5 2 4 0 3 0 0 0 0 0 1
            6 1 5 2 2 2 2 2 0 0 0 0 0 0
          INPUT
        end

        it "returns a command for inter to go chop off lemons" do
          is_expected.to eq("MSG hee hee; DROP 5; PLANT 1 BANANA; MOVE 3 7 4")
        end
      end
    end

    context "with seed=5774317116214727000 | nasing spešel quite close opp" do
      let(:field) do
        <<~FIELD
          ~~~~..#..~..........
          ...~~...~~..+.......
          ..~~....~~...1.+....
          ...~~~..~~..........
          #..~~~......#...~...
          ...~...#......~~~..#
          ..........~~..~~~...
          ....+.0...~~....~~..
          .......+..~~...~~...
          ..........~..#..~~~~
        FIELD
      end

      context "when turn 40 and unlikely to bootstrap new lemontrees" do
        let(:turn) { 40 }
        let(:input) do
          <<~INPUT
            10 9 9 9 10 1
            0 2 4 9 1 4
            20
            PLUM 5 1 4 12 3 0
            PLUM 14 8 4 12 3 0
            PLUM 18 8 4 12 3 0
            PLUM 1 1 4 12 3 0
            LEMON 2 9 4 12 3 0
            LEMON 17 0 4 12 3 0
            LEMON 18 5 4 12 3 0
            LEMON 1 4 4 12 3 0
            LEMON 1 8 4 12 3 0
            LEMON 18 1 4 12 3 0
            APPLE 14 9 4 20 3 3
            APPLE 5 0 4 20 3 3
            APPLE 9 4 4 20 3 0
            APPLE 10 5 4 20 3 0
            APPLE 13 5 4 20 3 0
            BANANA 3 9 4 6 3 0
            BANANA 16 0 4 6 3 0
            BANANA 10 2 4 6 3 0
            PLUM 13 4 3 10 0 3
            PLUM 13 3 2 8 0 8
            3
            0 0 5 7 1 1 1 1 0 0 0 0 0 0
            1 1 14 8 1 1 1 1 0 0 0 0 0 0
            2 1 11 2 3 2 2 2 0 0 0 0 0 2
          INPUT
        end

        it "returns a command to just go get lemon and iron, not bother with plant" do
          is_expected.to eq("MSG trns till LEMON 6; MOVE 0 5 8")
        end
      end

      context "when turn 40 and unlikely to bootstrap new lemontrees" do
        let(:turn) { 40 }
        let(:input) do
          <<~INPUT
            10 9 9 9 10 1
            1 2 4 9 1 6
            20
            PLUM 5 1 4 12 3 0
            PLUM 14 8 4 12 3 0
            PLUM 18 8 4 12 3 0
            PLUM 1 1 4 12 3 0
            LEMON 2 9 4 12 3 0
            LEMON 17 0 4 12 3 0
            LEMON 18 5 4 12 3 0
            LEMON 1 4 4 12 3 0
            LEMON 1 8 4 12 3 0
            LEMON 18 1 4 12 3 0
            APPLE 14 9 4 20 3 0
            APPLE 5 0 4 20 3 0
            APPLE 9 4 4 20 3 0
            APPLE 10 5 4 20 3 0
            APPLE 13 5 4 20 3 0
            BANANA 3 9 4 6 3 0
            BANANA 16 0 4 6 3 0
            BANANA 10 2 4 6 3 0
            PLUM 13 4 4 12 0 3
            PLUM 13 3 3 10 0 8
            3
            0 0 3 9 1 1 1 1 0 0 0 0 0 0
            1 1 13 3 1 1 1 1 0 0 0 0 0 0
            2 1 3 9 3 2 2 2 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to just go get lemon, not bother with plant" do
          is_expected.to eq("MSG trns till LEMON 2; MOVE 0 2 9")
        end
      end
    end

    context "with seed=-2976664274459909000 | no wet cells nearby, haard" do
      let(:field) do
        <<~FIELD
          .....#.1....~~~~
          ............~~~~
          ..+..........~~~
          ~~~........+.~~~
          ~~~.+........~~~
          ~~~..........+..
          ~~~~............
          ~~~~....0.#.....
        FIELD
      end

      context "when " do
        let(:turn) { 1 }
        let(:input) do
          <<~INPUT
            4 3 10 5 7 0
            4 3 10 5 7 0
            16
            PLUM 8 4 4 12 1 5
            PLUM 7 3 4 12 1 5
            LEMON 10 5 3 10 0 3
            LEMON 5 2 3 10 0 3
            LEMON 12 6 4 12 1 6
            LEMON 3 1 4 12 1 6
            LEMON 4 3 3 10 0 1
            LEMON 11 4 3 10 0 1
            APPLE 11 7 3 17 0 8
            APPLE 4 0 3 17 0 8
            BANANA 13 6 1 3 0 5
            BANANA 2 1 1 3 0 5
            BANANA 6 7 4 6 0 5
            BANANA 9 0 4 6 0 5
            BANANA 14 5 3 5 0 1
            BANANA 1 2 3 5 0 1
            2
            0 1 7 0 1 1 1 1 0 0 0 0 0 0
            1 0 8 7 1 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to hold off on inter since no point" do
          is_expected.to eq("MSG trns till PLUM 4; MOVE 1 8 6")
        end
      end
    end

    context "with seed=" do
      let(:field) do
        <<~FIELD
          ..........#~~~~~~.
          ......+...~~1~~...
          ..........~..~~...
          ...~.~~~.....~~~..
          ..~~~~......~~~~..
          ..~~~.....~~~.~...
          ...~~..~..........
          ...~~0~~...+......
          .~~~~~~#..........
        FIELD
      end

      context "when " do
        let(:turn) { 2 }
        let(:input) do
          <<~INPUT
            4 10 8 5 10 0
            4 10 8 5 10 0
            22
            PLUM 5 5 4 12 2 3
            PLUM 12 3 4 12 2 3
            PLUM 11 4 4 12 1 1
            PLUM 6 4 4 12 1 1
            LEMON 2 7 4 12 3 1
            LEMON 15 1 4 12 3 1
            LEMON 16 6 3 10 0 2
            LEMON 1 2 3 10 0 2
            LEMON 11 3 4 12 1 5
            LEMON 6 5 4 12 1 5
            APPLE 16 1 1 11 0 1
            APPLE 1 7 1 11 0 1
            APPLE 0 0 4 20 0 2
            APPLE 17 8 4 20 0 2
            APPLE 8 8 4 20 3 6
            APPLE 9 0 4 20 3 6
            BANANA 9 8 4 6 0 4
            BANANA 8 0 4 6 0 4
            BANANA 6 0 4 6 2 1
            BANANA 11 8 4 6 2 1
            BANANA 3 1 3 5 0 6
            BANANA 14 7 3 5 0 6
            2
            0 0 5 6 1 1 1 1 0 0 0 0 0 0
            1 1 12 2 1 1 1 1 0 0 0 0 0 0
          INPUT
        end

        it "returns a command to go get plum, not pic lemon, no sense planting anything" do
          is_expected.to eq("MSG trns till PLUM 2; MOVE 0 5 5")
        end
      end

      context "when chooper has ran outside base for some quick chop" do
        let(:turn) { 2 }
        let(:input) do
          <<~INPUT
            0 0 7 2 0 10
            0 0 7 2 0 0
            24
            PLUM 12 3 4 12 3 0
            PLUM 11 4 4 12 3 0
            LEMON 2 7 4 12 3 0
            LEMON 15 1 4 12 3 0
            LEMON 16 6 4 12 3 8
            LEMON 1 2 4 12 3 8
            LEMON 11 3 4 12 3 3
            APPLE 16 1 4 20 3 0
            APPLE 1 7 4 20 3 0
            APPLE 0 0 4 20 3 3
            APPLE 17 8 4 20 3 3
            APPLE 8 8 4 20 3 0
            APPLE 9 0 4 20 3 0
            BANANA 9 8 4 6 3 0
            BANANA 8 0 4 6 3 0
            BANANA 6 0 4 6 3 0
            BANANA 11 8 4 6 3 0
            BANANA 3 1 4 6 3 4
            BANANA 14 7 4 6 3 4
            BANANA 12 2 4 6 1 1
            BANANA 11 2 4 6 1 4
            BANANA 10 3 3 5 0 2
            BANANA 5 5 2 4 0 3
            BANANA 5 6 1 3 0 4
            4
            0 0 5 6 1 1 1 1 0 0 0 0 0 0
            1 1 11 3 1 1 1 1 0 1 0 0 0 0
            2 0 8 7 2 3 0 3 0 0 0 0 0 0
            3 1 7 4 2 3 0 3 0 0 0 0 0 3
          INPUT
        end

        it "returns a command for chopper to prefer quick-to-chop banana to apple" do
          is_expected.to contain("MSG beeline; MOVE 2 9 8")
        end
      end
    end

    # EXAMPLE
    context "with seed=" do
      let(:field) do
        <<~FIELD

        FIELD
      end

      context "when " do
        let(:turn) { 1 }
        let(:input) do
          <<~INPUT

          INPUT
        end

        xit "returns " do
          is_expected.to eq("TODO")
        end
      end
    end
  end
end
