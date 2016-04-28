describe MiqPreloader do
  describe ".preload" do
    it "preloads once from an object" do
      ems = FactoryGirl.create(:ems_infra)
      expect(ems.vms).not_to be_loaded
      expect { preload(ems, :vms) }.to match_query_limit_of(1)
      expect(ems.vms).to be_loaded
      expect { preload(ems, :vms) }.to match_query_limit_of(0)
    end

    it "preloads from an array" do
      emses = FactoryGirl.create_list(:ems_infra, 2)
      expect { preload(emses, :vms) }.to match_query_limit_of(1)
      expect(emses[0].vms).to be_loaded
    end

    it "preloads from an association" do
      ems = FactoryGirl.create(:ems_infra)
      FactoryGirl.create_list(:vm, 2, :ext_management_system => ems)

      emses = ExtManagementSystem.all
      expect { preload(emses, :vms) }.to match_query_limit_of(2)
    end

    def preload(*args)
      MiqPreloader.preload(*args)
    end
  end

  describe ".preload_and_map" do
    it "preloads from an object" do
      ems = FactoryGirl.create(:ems_infra)
      FactoryGirl.create_list(:vm, 2, :ext_management_system => ems)

      vms = nil
      expect { vms = preload_and_map(ems, :vms) }.to match_query_limit_of(1)
      expect { expect(vms.size).to eq(2) }.to match_query_limit_of(0)
    end

    it "preloads from an association" do
      ems = FactoryGirl.create(:ems_infra)
      FactoryGirl.create_list(:vm, 2, :ext_management_system => ems)

      emses = ExtManagementSystem.all
      expect { preload_and_map(emses, :vms) }.to match_query_limit_of(2)
    end

    def preload_and_map(*args)
      MiqPreloader.preload_and_map(*args)
    end
  end
end
