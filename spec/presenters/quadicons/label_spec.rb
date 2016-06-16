describe Quadicons::Label, :type => :helper do
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:record) { FactoryGirl.create(:vm_redhat) }
  subject(:label) { Quadicons::Label.new(record, kontext) }

  context "when in listnav" do
    before do
      kontext.listnav = true
    end

    it 'does not render a link' do
      expect(label.render).not_to have_selector("a")
    end
  end
end
