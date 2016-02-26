describe MiqSearch do
  describe '#descriptions' do
    it "hashes" do
      srchs = [
        FactoryGirl.create(:miq_search, :description => 'a'),
        FactoryGirl.create(:miq_search, :description => 'b'),
        FactoryGirl.create(:miq_search, :description => 'c')
      ]

      expect(MiqSearch.descriptions).to eq(
        srchs[0].id.to_s => srchs[0].description,
        srchs[1].id.to_s => srchs[1].description,
        srchs[2].id.to_s => srchs[2].description)
    end

    it "supports scopes" do
      srchs = [
        FactoryGirl.create(:miq_search, :description => 'a', :db => 'Vm'),
        FactoryGirl.create(:miq_search, :description => 'b', :db => 'Vm'),
        FactoryGirl.create(:miq_search, :description => 'c', :db => 'Host')
      ]

      expect(MiqSearch.where(:db => 'Vm').descriptions).to eq(
        srchs[0].id.to_s => srchs[0].description,
        srchs[1].id.to_s => srchs[1].description)
    end
  end

  let(:vm_location_search) do
    FactoryGirl.create(:miq_search,
                       :db     => "Vm",
                       :filter => MiqExpression.new("=" => {"field" => "Vm-location", "value" => "good"})
                      )
  end

  let(:matched_vms) { FactoryGirl.create_list(:vm_vmware, 2, :location => "good") }
  let(:other_vms)   { FactoryGirl.create_list(:vm_vmware, 1, :location => "other") }
  let(:all_vms)     { matched_vms + other_vms }
  let(:partial_matched_vms) { [matched_vms.first] }
  let(:partial_vms) { partial_matched_vms + other_vms }

  # general use cases around rbac
  describe "#search" do
    it "brings back filtered targets" do
      all_vms
      expect(vm_location_search.search.first).to match_array(matched_vms.map(&:id))
    end

    it "resects search options" do
      all_vms
      expect(vm_location_search.search(:results_format => :objects).first).to match_array(matched_vms)
    end
  end

  describe "#filtered" do
    it "works with models" do
      all_vms
      expect(vm_location_search.filtered(Vm)).to match_array(matched_vms)
    end

    it "works with scopes" do
      all_vms
      expect(vm_location_search.filtered(Vm.all)).to match_array(matched_vms)
    end

    it "finds elements only in the array" do
      all_vms
      expect(vm_location_search.filtered(partial_vms)).to match_array(partial_matched_vms)
    end

    it "brings back all for unspecified target" do
      all_vms
      expect(vm_location_search.filtered(nil)).to match_array(matched_vms)
    end

    it "brings back empty array for empty arrays" do
      all_vms
      expect(vm_location_search.filtered([])).to match_array([])
    end
  end

  describe ".search" do
    it "uses an existing search" do
      all_vms
      results = MiqSearch.search(vm_location_search.id, "Vm", :results_format => :objects).first
      expect(results).to match_array(matched_vms)
    end

    it "calls Rbac directly if there is no search" do
      all_vms
      results = MiqSearch.search(0, "Vm", :results_format => :objects).first
      expect(results).to match_array(all_vms)
    end
  end

  describe ".filtered" do
    it "uses an existing search" do
      all_vms
      results = MiqSearch.filtered(vm_location_search.id, "Vm", partial_vms)
      expect(results).to match_array(partial_matched_vms)
    end

    it "calls Rbac directly for no search" do
      all_vms
      results = MiqSearch.filtered(0, "Vm", partial_vms)
      expect(results).to match_array(partial_vms)
    end
  end
end
