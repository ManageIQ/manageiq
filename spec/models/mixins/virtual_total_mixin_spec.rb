describe VirtualTotalMixin do
  describe ".virtual_total (with real relation ems#total_vms)" do
    let(:base_model) { ExtManagementSystem }
    it "sorts by total" do
      ems0 = model_with_children(0)
      ems2 = model_with_children(2)
      ems1 = model_with_children(1)

      expect(base_model.order(base_model.arel_attribute(:total_vms)).pluck(:id))
        .to eq([ems0, ems1, ems2].map(&:id))
    end

    it "calculates totals locally" do
      expect(model_with_children(0).total_vms).to eq(0)
      expect(model_with_children(2).total_vms).to eq(2)
    end

    def model_with_children(count)
      FactoryGirl.create(:ext_management_system).tap do |ems|
        FactoryGirl.create_list(:vm, count, :ext_management_system => ems) if count > 0
      end
    end
  end

  describe ".virtual_total (with virtual relation (resource_pool#total_vms)" do
    let(:base_model) { ResourcePool }
    # it can not sort by virtual

    it "calculates totals locally" do
      expect(model_with_children(0).total_vms).to eq(0)
      expect(model_with_children(2).total_vms).to eq(2)
    end

    def model_with_children(count)
      FactoryGirl.create(:resource_pool).tap do |pool|
        count.times do |_i|
          vm = FactoryGirl.create(:vm)
          vm.with_relationship_type("ems_metadata") { vm.set_parent pool }
        end
      end
    end
  end
end
