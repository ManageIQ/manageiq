describe Quadicons::ConfigurationManagerQuadicon, :type => :helper do
  let(:record) { FactoryGirl.create(:configuration_manager_foreman) }
  let(:kontext) { Quadicons::Context.new(helper) }
  subject(:quadicon) { Quadicons::ConfigurationManagerQuadicon.new(record, kontext) }

  context "in explorer, not embedded" do
    before do
      kontext.embedded = false
      kontext.explorer = true
    end

    it 'renders with a vendor icon' do
      expect(quadicon.quadrants).to include(:config_vendor)
    end
  end
end
