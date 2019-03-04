describe MiqSearch do
  describe '#descriptions' do
    it "hashes" do
      srchs = [
        FactoryBot.create(:miq_search, :description => 'a'),
        FactoryBot.create(:miq_search, :description => 'b'),
        FactoryBot.create(:miq_search, :description => 'c')
      ]

      expect(MiqSearch.descriptions).to eq(
        srchs[0].id.to_s => srchs[0].description,
        srchs[1].id.to_s => srchs[1].description,
        srchs[2].id.to_s => srchs[2].description)
    end

    it "supports scopes" do
      srchs = [
        FactoryBot.create(:miq_search, :description => 'a', :db => 'Vm'),
        FactoryBot.create(:miq_search, :description => 'b', :db => 'Vm'),
        FactoryBot.create(:miq_search, :description => 'c', :db => 'Host')
      ]

      expect(MiqSearch.where(:db => 'Vm').descriptions).to eq(
        srchs[0].id.to_s => srchs[0].description,
        srchs[1].id.to_s => srchs[1].description)
    end
  end

  let(:vm_location_search) do
    FactoryBot.create(:miq_search,
                       :db     => "Vm",
                       :filter => MiqExpression.new("=" => {"field" => "Vm-location", "value" => "good"})
                      )
  end

  let(:matched_vms) { FactoryBot.create_list(:vm_vmware, 2, :location => "good") }
  let(:other_vms)   { FactoryBot.create_list(:vm_vmware, 1, :location => "other") }
  let(:all_vms)     { matched_vms + other_vms }
  let(:partial_matched_vms) { [matched_vms.first] }
  let(:partial_vms) { partial_matched_vms + other_vms }

  describe "#quick_search?" do
    let(:qs) { MiqExpression.new("=" => {"field" => "Vm-name", "value" => :user_input}) }
    it "supports no filter" do
      expect(FactoryBot.build(:miq_search, :filter => nil)).not_to be_quick_search
    end

    it "supports a filter" do
      expect(vm_location_search).not_to be_quick_search
    end

    it "supports a quick search" do
      expect(FactoryBot.build(:miq_search, :filter => qs)).to be_quick_search
    end
  end

  describe "#results" do
    it "respects filter" do
      all_vms
      expect(vm_location_search.results).to match_array(matched_vms)
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

    it "brings back empty array for empty arrays" do
      all_vms
      expect(vm_location_search.filtered([])).to match_array([])
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

  describe "#destroy" do
    let(:search) { FactoryBot.create(:miq_search) }

    it "destroys search if miq_schedule does not use it" do
      expect { search.destroy! }.not_to raise_error
    end

    it "does not destroy search if it referenced in at least one miq_schedule" do
      schedules = double
      allow(search).to receive(:miq_schedules).and_return(schedules)
      allow(schedules).to receive(:empty?).and_return(false)

      expect { expect { search.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed) }.to_not(change { MiqSearch.count })
      expect(search.errors[:base][0]).to eq("Search is referenced in a schedule and cannot be deleted")
    end
  end
end
