describe VirtualTotal do
  describe ".virtual_total (with real has_many relation ems#total_vms)" do
    let(:base_model) { ExtManagementSystem }
    it "sorts by total" do
      ems0 = model_with_children(0)
      ems2 = model_with_children(2)
      ems1 = model_with_children(1)

      expect(base_model.order(:total_vms).pluck(:id))
        .to eq([ems0, ems1, ems2].map(&:id))
    end

    it "calculates totals locally" do
      expect(model_with_children(0).total_vms).to eq(0)
      expect(model_with_children(2).total_vms).to eq(2)
    end

    it "can bring back totals in primary query" do
      m3 = model_with_children(3)
      m1 = model_with_children(1)
      m2 = model_with_children(2)
      mc = m1.class
      expect {
        ms = mc.select(:id, mc.arel_attribute(:total_vms).as("total_vms"))
        expect(ms).to match_array([m3, m2, m1])
        expect(ms.map(&:total_vms)).to match_array([3, 2, 1])
      }.to match_query_limit_of(1)
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

    it "is not defined in sql" do
      expect(base_model.attribute_supported_by_sql?(:total_vms)).to be(false)
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

  describe ".virtual_total (with through relation (host#v_total_storages)" do
    let(:base_model) { Host }

    it "calculates totals locally" do
      expect(model_with_children(0).v_total_storages).to eq(0)
      expect(model_with_children(2).v_total_storages).to eq(2)
    end

    it "is not defined in sql" do
      expect(base_model.attribute_supported_by_sql?(:v_total_storages)).to be(false)
    end

    def model_with_children(count)
      FactoryGirl.create(:host).tap do |host|
        count.times { host.storages.create(FactoryGirl.attributes_for(:storage)) }
      end.reload
    end
  end
end
