describe Quadicons::Quadrants::GuestCompliance, :type => :helper do
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:item) { FactoryGirl.build(:vm_vmware) }
  subject(:gcomp) { Quadicons::Quadrants::GuestCompliance.new(item, kontext) }

  context "when item passes compliance" do
    before(:each) do
      allow(item).to receive(:passes_profiles?) { true }
    end

    it 'renders a checkmark' do
      expect(gcomp.render).to match(/check.*\.png/)
    end
  end

  context "when compliance is N/A" do
    before(:each) do
      allow(item).to receive(:passes_profiles?) { "N/A" }
    end

    it 'renders NA' do
      expect(gcomp.render).to match(/na.*\.png/)
    end
  end

  context "when compliance is something else" do
    before(:each) do
      allow(item).to receive(:passes_profiles?) { nil }
    end

    it 'renders an X' do
      expect(gcomp.render).to match(/x.*\.png/)
    end
  end
end
