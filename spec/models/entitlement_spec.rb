require 'rails_helper'

describe Entitlement do
  describe "::remove_tag_from_all_managed_filters" do
    let!(:entitlement1) { FactoryGirl.create(:entitlement) }
    let!(:entitlement2) { FactoryGirl.create(:entitlement) }
    let(:filters) do
      [["/managed/prov_max_memory/test", "/managed/prov_max_memory/1024"], ["/managed/my_name/test"]]
    end

    before do
      entitlement1.set_managed_filters([["/managed/prov_max_memory/test", "/managed/prov_max_memory/1024"],
                                        ["/managed/my_name/test"]])
      entitlement2.set_managed_filters([["/managed/prov_max_memory/1024"]])
      [entitlement1, entitlement2].each(&:save)
    end

    it "removes managed filter from all groups" do
      described_class.remove_tag_from_all_managed_filters("/managed/prov_max_memory/1024")

      expect(entitlement1.reload.get_managed_filters).to match_array([["/managed/prov_max_memory/test"],
                                                                      ["/managed/my_name/test"]])
      expect(entitlement2.reload.get_managed_filters).to be_empty
    end
  end
end
