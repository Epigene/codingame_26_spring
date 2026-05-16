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
          ...
          .0.
          ...
        FIELD
      end

      it "inits the grid such that camp can be left by trolls, but never returned to" do
        expect(controller.grid["1 0"]).to eq(["0 0", "2 0"].to_set)
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
        is_expected.to eq("MSG turns till PLUM 2; MOVE 0 9 7")
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
        is_expected.to eq("MSG turns till LEMON 2; MOVE 0 9 8")
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

    context "with seed=3070472706778279400 | later in the game, chopping wars" do
      let(:field) do
        <<~FIELD
          ..~~~..~........
          ..~~~~.~..0...+.
          +..~...~~.......
          .#.~............
          ............~.#.
          .......~~...~..+
          .+...1..~.~~~~..
          ........~..~~~..
        FIELD
      end

      let(:input) do
        <<~INPUT
          0 0 5 0 0 12
          2 2 5 2 1 11
          11
          PLUM 0 1 4 12 3 0
          PLUM 15 6 4 12 3 0
          PLUM 13 3 4 12 3 0
          LEMON 0 3 4 12 3 0
          LEMON 15 4 4 12 3 0
          APPLE 9 5 4 16 3 0
          APPLE 15 7 4 20 3 0
          APPLE 0 0 4 20 3 0
          BANANA 14 0 4 6 3 0
          BANANA 9 0 4 1 0 4
          BANANA 9 2 2 4 0 2
          4
          0 1 9 0 1 1 1 1 0 0 0 0 0 0
          1 0 13 0 1 1 1 1 0 0 0 0 0 0
          2 1 9 5 1 1 0 2 0 0 0 0 0 0
          3 0 10 2 2 4 0 3 0 0 0 0 0 0
        INPUT
      end

      it "returns a command for chopper to go contest the apple tree being chopped by opp" do
        is_expected.to eq("MSG chop warz; MOVE 3 9 3; MOVE 1 14 0")
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

    context "with seed=388785412389555300" do
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
            0 1 4 9 1 0
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

        it "returns a command for inter to get iron and helper to plant lemon he's carrying" do
          is_expected.to eq("MOVE 2 11 1; PLANT 1 LEMON")
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
