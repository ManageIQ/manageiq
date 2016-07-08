describe MiqAeClassHelper do
  let(:dummy_class) { Class.new.include(MiqAeClassHelper).new }

  describe "#git_enabled?" do
    context "when the record is of class MiqAeDomain" do
      let(:record) { MiqAeDomain.new }

      before do
        allow(record).to receive(:git_enabled?).and_return(git_enabled?)
      end

      context "when the record is git enabled" do
        let(:git_enabled?) { true }

        it "returns true" do
          expect(dummy_class.git_enabled?(record)).to eq(true)
        end
      end

      context "when the record is not git enabled" do
        let(:git_enabled?) { false }

        it "returns false" do
          expect(dummy_class.git_enabled?(record)).to eq(false)
        end
      end
    end

    context "when the record is not of class MiqAeDomain" do
      let(:record) { nil }

      it "returns false" do
        expect(dummy_class.git_enabled?(record)).to eq(false)
      end
    end
  end
end
