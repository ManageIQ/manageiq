require 'wbem'

describe Quadicons::MiqCimInstanceQuadicon, :type => :helper do
  let(:record) do
    obj = WBEM::CIMInstance.new("ONTAP_StorageSystem")
    obj["Name"] = "FooBar"

    FactoryGirl.create(:miq_cim_instance, :obj => obj)
  end

  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::MiqCimInstanceQuadicon.new(record, kontext) }

  describe "setup" do
    subject(:quadicon) { instance }

    it 'renders a type_icon quadrant' do
      expect(quadicon.quadrant_list).to include(:type_icon)
    end

    it 'renders in single mode' do
      expect(quadicon.render_single?).to eq(true)
    end
  end

  describe "rendering" do
    subject(:rendered) { instance.render }

    # FIXME: make url building more explicit

    before do
      expect(kontext).to receive(:url_for_record).at_least(:once) do
        "/ontap_file_share/cim_base_storage_extents/#{ApplicationRecord.compress_id(record.id)}"
      end

      allow(controller).to receive(:default_url_options) do
        {:controller => "provider_foreman"}
      end
    end

    it 'renders a miq_cim_instance image' do
      expect(rendered).to have_selector("img[src*='miq_cim_instance']")
    end

    it 'is titled after the evm_display_name' do
      expect(rendered).to match(/title\s*=\s*\"#{record.evm_display_name}\"/)
    end
  end
end
