
describe "Quadicon for EmsCluster", :type => :helper do
  let(:record) { FactoryGirl.create(:ems_cluster) }
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::Base.new(record, kontext) }

  describe "setup" do
    subject(:quadicon) { instance }

    it 'includes a type_icon quadrant' do
      expect(quadicon.quadrant_list).to include(:type_icon)
    end
  end

  describe "rendering" do
    subject(:rendered) { instance.render }

    it 'includes the ems-cluster icon' do
      expect(rendered).to have_selector("img[src*='emscluster']")
    end

    context "when type not is listnav" do
      before do
        kontext.listnav = false
      end

      context "when not embedded or showlinks" do
        before do
          kontext.embedded  = false
          kontext.showlinks = false
        end

        it 'links to the record' do
          cid = ApplicationRecord.compress_id(record.id)
          expect(rendered).to have_selector("a[href^='/ems_cluster/show/#{cid}']")
        end
      end

      context "when embedded" do
        before do
          kontext.embedded = true
          allow(controller).to receive(:default_url_options) do
            {:controller => "ems_cluster", :action => "show"}
          end
        end

        it 'links to an inferred url' do
          expect(rendered).to have_selector("a[href^='/ems_cluster/show']")
        end
      end
    end
  end
end
