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
        is_expected.to eq("MOVE 4 9 8; DROP 0") # since helper 0 is trapped, remain to work where one is
      end
    end

    context "when initialized with seed=6972392475458301000 | when enough resources to train the chopper and helper is on 9 7 plum" do
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

    # EXAMPLE
    context "when initialized with seed TODO" do
      let(:field) do
        <<~FIELD

        FIELD
      end

      let(:input) do
        <<~INPUT

        INPUT
      end

      xit "returns " do
        is_expected.to eq("TRAIN 1 1 1 0; MOVE 0 6 2")
      end
    end
  end
end
