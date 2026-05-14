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
  end
end
