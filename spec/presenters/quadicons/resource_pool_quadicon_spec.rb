describe Quadicons::ResourcePoolQuadicon, :type => :helper do
  let(:record) { FactoryGirl.build(:resource_pool) }
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::ResourcePoolQuadicon.new(record, kontext) }

  describe "setup" do
    subject(:quadicon) { instance }

    it 'includes a type icon quadrant' do
      expect(quadicon.quadrant_list).to include(:type_icon)
    end
  end

  describe "rendering" do
    subject(:rendered) { instance.render }

    context "when vapp" do
      before do
        record.vapp = true
      end

      it 'renders a vapp image' do
        expect(rendered).to have_selector('img[src*="vapp"]')
      end
    end

    context "when not vapp" do
      it 'renders a resource_pool icon' do
        expect(rendered).to have_selector('img[src*="resource_pool"]')
      end
    end

    context "when not listnav" do
      before do
        kontext.listnav = false
      end

      context "when embedded" do
        before do
          kontext.embedded = true
        end

        it 'has a link to nowhere' do
          expect(rendered).to have_selector("a")
          expect(rendered).to include('href=""')
        end
      end

      context "when not embedded" do
        let(:record) { FactoryGirl.create(:resource_pool) }

        before do
          kontext.embedded = false
        end

        it 'links to the record' do
          cid = ApplicationRecord.compress_id(record.id)
          expect(subject).to have_selector("a[href*='resource_pool/show/#{cid}']")
        end
      end
    end

    context "when listnav" do
      before do
        kontext.listnav = true
      end

      it 'has no anchor tag' do
        expect(rendered).not_to have_selector("a")
      end
    end
  end
end
