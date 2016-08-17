require 'wbem'

describe Quadicons::Base, :type => :helper do
  let(:record) do
    obj = WBEM::CIMInstance.new("ONTAP_StorageSystem")
    obj["Name"] = "FooBar"
    obj["DeviceID"] = "Baz"

    FactoryGirl.create(:cim_storage_extent, :obj => obj)
  end

  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::Base.new(record, kontext) }

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

    before do
      expect(kontext).to receive(:url_for_record).at_least(:once) do
        "/ontap_file_share/cim_base_storage_extents/#{ApplicationRecord.compress_id(record.id)}"
      end
    end

    it 'includes a cim_base_storage_extent img' do
      expect(rendered).to have_selector("img[src*='cim_base_storage_extent']")
    end

    it 'is titled after the evm_display_name' do
      expect(rendered).to match(/title\s*=\s*\"#{record.evm_display_name}\"/)
    end
  end
end
