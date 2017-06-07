describe ApplicationHelper::Button::CockpitConsole do
  describe '#disabled?' do
    before { @record = FactoryGirl.create(:vm) }
    let(:view_context) { setup_view_context_with_sandbox({}) }
    let(:button) { described_class.new(view_context, {}, {:record => @record}, {}) }
    context "when the power state of the record is 'on'" do
      let(:power_state) { 'on' }
      it "returns false" do
        expect(button[:disabled?]).to be_falsey
      end
    end
    context "when the power state of the record is not 'on'" do
      let(:power_state) { 'unknown' } # orphaned and archived VM's
      it "returns true" do
        expect(button[:disabled?]).to be_nil
      end
    end
    context "when platform is 'windows'" do
      it "returns true" do
        allow(@record).to receive(:platform).and_return('windows')
        expect(button[:disabled?]).to be_nil
      end
    end
    context "when platform is 'linux'" do
      it "returns false" do
        allow(@record).to receive(:platform).and_return('linux')
        expect(button[:disabled?]).to be_falsey
      end
    end
  end
end
