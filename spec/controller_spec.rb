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

    context "when initialized with seed -5938658670755382000" do
      let(:field) do
        <<~FIELD
          ................
          .............1..
          ................
          ................
          ................
          ................
          ..0.............
          ................
        FIELD
      end

      let(:input) do
        <<~INPUT
          0 0 0 0 0 0
          0 0 0 0 0 0
          18
          PLUM 2 7 4 12 1 6
          PLUM 13 0 4 12 1 6
          PLUM 4 5 4 12 1 5
          PLUM 11 2 4 12 1 5
          PLUM 4 2 3 10 0 3
          PLUM 11 5 3 10 0 3
          LEMON 0 2 3 10 0 1
          LEMON 15 5 3 10 0 1
          APPLE 13 5 2 14 0 9
          APPLE 2 2 2 14 0 9
          APPLE 12 3 4 20 0 5
          APPLE 3 4 4 20 0 5
          APPLE 0 4 4 20 1 3
          APPLE 15 3 4 20 1 3
          BANANA 2 5 4 6 0 4
          BANANA 13 2 4 6 0 4
          BANANA 6 6 3 5 0 2
          BANANA 9 1 3 5 0 2
          2
          0 0 2 6 1 1 1 0 0 0 0 0 0 0
          1 1 13 1 1 1 1 0 0 0 0 0 0 0
        INPUT
      end

      it "returns a move to go harvest the closest fruit" do
        is_expected.to eq("MOVE 0 2 7")
      end
    end

    context "when initialized with seed -6547937984084192000 | wood 1 planting" do
      let(:field) do
        <<~FIELD
          ................
          .......0........
          ................
          ................
          ................
          ................
          ........1.......
          ................
        FIELD
      end

      let(:input) do
        <<~INPUT
          5 7 10 9 0 0
          5 7 10 9 0 0
          16
          PLUM 0 7 2 8 0 8
          PLUM 15 0 2 8 0 8
          LEMON 9 1 4 12 2 5
          LEMON 6 6 4 12 2 5
          APPLE 9 2 3 17 0 8
          APPLE 6 5 3 17 0 8
          APPLE 14 1 4 20 0 4
          APPLE 1 6 4 20 0 4
          APPLE 0 5 4 20 2 8
          APPLE 15 2 4 20 2 8
          BANANA 11 0 4 6 3 5
          BANANA 4 7 4 6 3 5
          BANANA 9 5 4 6 2 3
          BANANA 6 2 4 6 2 3
          BANANA 12 1 3 5 0 4
          BANANA 3 6 3 5 0 4
          2
          0 0 7 1 1 1 1 0 0 0 0 0 0 0
          1 1 8 6 1 1 1 0 0 0 0 0 0 0
        INPUT
      end

      it "returns a move to go harvest the closest high-yield fruit (banana, not lemon) and train a new worker" do
        is_expected.to eq("TRAIN 1 1 1 0; MOVE 0 6 2")
      end
    end

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
