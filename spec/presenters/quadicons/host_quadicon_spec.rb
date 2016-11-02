describe Quadicons::HostQuadicon, :type => :helper do
  let(:record) { FactoryGirl.create(:host) }
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::HostQuadicon.new(record, kontext) }

  before do
    kontext.settings = {:quadicons => {:host => true}}
  end

  describe "setup" do
    subject(:quadicon) { instance }

    context "when @settings includes :quadicon => :host" do
      before do
        kontext.settings = {:quadicons => {:host => true}}
      end

      it "includes a vm count quadrant" do
        expect(quadicon.quadrant_list).to include(:guest_count)
      end

      it "includes a state quadrant" do
        expect(quadicon.quadrant_list).to include(:normalized_state)
      end

      it "includes a host vendor icon" do
        expect(quadicon.quadrant_list).to include(:host_vendor)
      end

      it "includes an auth state icon" do
        expect(quadicon.quadrant_list).to include(:auth_status)
      end
    end
  end

  describe "rendering" do
    subject(:rendered) { instance.render }

    context "when @settings[:quadicon][:host] is truthy" do
      it 'renders the vm count' do
        expect(rendered).to include("<span class=\"quadrant-value\">0")
      end

      it 'renders the state icon' do
        expect(rendered).to have_selector("img[src*='currentstate-archived']")
      end

      it 'renders a vendor icon' do
        expect(rendered).to have_selector("img[src*='vendor-unknown']")
      end

      it 'renders a quadicon with an auth status img' do
        allow(record).to receive(:authentication_status) { "Valid" }
        expect(rendered).to have_selector("img[src*='checkmark']")
      end

      it 'renders a shield badge' do
        expect(rendered).to have_selector('img[src*="shield"]')
      end
    end

    context "when @settings[:quadicon][:host] is falsey" do
      before do
        kontext.settings = {:quadicons => {:host => false}}
      end

      it 'renders a vendor icon' do
        expect(rendered).to have_selector("img[src*='vendor-unknown']")
      end

      it 'does not render any other quadrants' do
        expect(rendered).not_to have_selector(".quadrant-guest_count")
        expect(rendered).not_to have_selector("img[src*='currentstate-archived']")
        expect(rendered).not_to have_selector("img[src*='checkmark']")
      end
    end

    context "when type is listnav" do
      before do
        kontext.listnav = true
      end

      # include_examples :no_link_for_listnav
      it 'has no link when type is listnav' do
        expect(rendered).not_to have_selector("a")
      end
    end

    context "when type is not listnav" do
      before do
        kontext.listnav = false
      end

      context "when not embedded or showlinks" do
        before(:each) do
          kontext.embedded = false
        end

        it 'links to /host/edit when @edit[:hostnames] is present' do
          kontext.edit = {:hostitems => true}
          expect(rendered).to have_selector("a[href^='/host/edit']")
        end

        it 'links to the record with no @edit' do
          kontext.edit = nil
          cid = ApplicationRecord.compress_id(record.id)
          expect(rendered).to have_selector("a[href^='/host/show/#{cid}']")
        end
      end

      context "when embedded" do
        before do
          kontext.edit = {:hostitems => false}
          kontext.embedded = true
          allow(controller).to receive(:default_url_options) do
            {:controller => "host", :action => "show"}
          end
        end

        it 'links to an inferred url' do
          expect(rendered).to have_selector("a[href^='/host/show']")
        end
      end
    end
  end
end
