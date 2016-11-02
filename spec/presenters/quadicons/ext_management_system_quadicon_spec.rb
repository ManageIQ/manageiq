describe Quadicons::ExtManagementSystemQuadicon, :type => :helper do
  let(:record) { FactoryGirl.build(:ems_infra) }
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::ExtManagementSystemQuadicon.new(record, kontext) }

  describe "setup" do
    subject(:quadicon) { instance }

    it 'includes a type_icon quadrant' do
      expect(quadicon.quadrant_list).to include(:type_icon)
    end
  end

  describe "rendering" do
    subject(:rendered) { instance.render }

    before do
      kontext.settings = {:quadicons => {:ems => true}}
      allow(record).to receive(:hosts).and_return(%w(foo bar))
      allow(record).to receive(:image_name).and_return("foo")
    end

    it "doesn't display IP Address in the tooltip" do
      expect(rendered).not_to match(/IP Address/)
    end

    it "displays Host Name in the tooltip" do
      expect(rendered).to match(/Hostname/)
    end

    context "when type is not listicon" do
      let(:record) { FactoryGirl.create(:ems_infra) }

      before do
        kontext.listicon = true
      end

      it 'links to the record (with full id)' do
        expect(subject).to have_selector("a[href*='ems_infra/#{record.id}']")
      end
    end
  end
end
