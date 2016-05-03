describe VirtualTotalMixin do
  describe "ems" do
    # virtual_total :total_vms, :vms
    it "sorts by total" do
      ems0 = ems_with_vms(0)
      ems2 = ems_with_vms(2)
      ems1 = ems_with_vms(1)

      expect(ExtManagementSystem.order(ExtManagementSystem.arel_attribute(:total_vms)).pluck(:id))
        .to eq([ems0, ems1, ems2].map(&:id))
    end

    it "calculates totals locally" do
      expect(ems_with_vms(0).total_vms).to eq(0)
      expect(ems_with_vms(2).total_vms).to eq(2)
    end

    def ems_with_vms(count)
      FactoryGirl.create(:ext_management_system).tap do |ems|
        FactoryGirl.create_list(:vm, count, :ext_management_system => ems) if count > 0
      end
    end
  end
end
