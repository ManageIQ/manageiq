RSpec.describe MiqFilter do
  let(:ems)             { FactoryBot.create(:ems_vmware, :name => 'ems') }
  let(:datacenter)      { FactoryBot.create(:ems_folder, :name => "Datacenters", :ext_management_system => ems).tap { |dc| dc.parent = ems } }
  let(:mtc)             { FactoryBot.create(:datacenter, :name => "MTC", :ext_management_system => ems).tap { |mtc| mtc.parent = datacenter } }
  let(:ems_folder_path) { "/belongsto/ExtManagementSystem|#{ems.name}" }
  let(:mtc_folder_path) { "#{ems_folder_path}/EmsFolder|#{datacenter.name}/EmsFolder|#{mtc.name}" }
  let(:host_folder)     { FactoryBot.create(:ems_folder, :name => "host", :ext_management_system => ems).tap { |hf| hf.parent = mtc } }
  let(:host_1)          { FactoryBot.create(:host_vmware, :name => "Host_1", :ext_management_system => ems).tap { |h| h.parent = host_folder } }
  let(:host_2)          { FactoryBot.create(:host_vmware, :name => "Host_2", :ext_management_system => ems).tap { |h| h.parent = host_folder } }

  let(:mtc_folder_path_with_host_folder) { "#{mtc_folder_path}/EmsFolder|host" }
  let(:mtc_folder_path_with_host_1)      { "#{mtc_folder_path_with_host_folder}/Host|#{host_1.name}" }

  describe ".apply_belongsto_filters" do
    def apply_belongsto_filters(*args)
      MiqFilter.apply_belongsto_filters(*args)
    end

    it "returns all parent's Host objects when most-specialized filter is the Host object" do
      input_objects = [host_1, host_2]
      results = apply_belongsto_filters(input_objects, [mtc_folder_path_with_host_1])
      expect(results).to match_array(input_objects)
    end

    it "returns all Host objects when most-specialized filter is Host folder" do
      input_objects = [host_1, host_2]
      results = apply_belongsto_filters(input_objects, [mtc_folder_path_with_host_folder])
      expect(results).to match_array(input_objects)
    end
  end

  describe ".belongsto2object_list" do
    def belongsto2object_list(*args)
      MiqFilter.belongsto2object_list(*args)
    end

    it "converts path" do
      mtc_folder_object_path = [ems, datacenter, mtc]
      expect(belongsto2object_list(mtc_folder_path)).to match_array(mtc_folder_object_path)
    end

    it "converts path with 'host'" do
      host_folder_object_path = [ems, datacenter, mtc, host_folder]
      expect(belongsto2object_list(mtc_folder_path_with_host_folder)).to match_array(host_folder_object_path)
    end

    it "converts path with 'Host_1'" do
      host_object_path = [ems, datacenter, mtc, host_folder, host_1]
      expect(belongsto2object_list(mtc_folder_path_with_host_1)).to match_array(host_object_path)
    end

    it "converts path with 'Host_1' when another 'Host_1' exists on another EMS" do
      host_object_path = [ems, datacenter, mtc, host_folder, host_1]
      FactoryBot.create(:host_vmware, :name => "Host_1")

      expect(belongsto2object_list(mtc_folder_path_with_host_1)).to match_array(host_object_path)
    end

    it "converts path with 'Host_1' when another 'Host_1' exists on the same EMS at a different depth" do
      host_object_path = [ems, datacenter, mtc, host_folder, host_1]
      mtc2 = FactoryBot.create(:datacenter, :name => "MTC2", :ext_management_system => ems).tap { |mtc| mtc.parent = datacenter }
      FactoryBot.create(:host_vmware, :name => "Host_1", :ext_management_system => ems).tap { |h| h.parent = mtc2 }

      expect(belongsto2object_list(mtc_folder_path_with_host_1)).to match_array(host_object_path)
    end

    it "converts path with 'Host_1' when another 'Host_1' exists on the same EMS at the same depth" do
      host_object_path = [ems, datacenter, mtc, host_folder, host_1]
      mtc2 = FactoryBot.create(:datacenter, :name => "MTC2", :ext_management_system => ems).tap { |mtc| mtc.parent = datacenter }
      hf2 = FactoryBot.create(:ems_folder, :name => "host", :ext_management_system => ems).tap { |hf| hf.parent = mtc2 }
      FactoryBot.create(:host_vmware, :name => "Host_1", :ext_management_system => ems).tap { |h| h.parent = hf2 }

      expect(belongsto2object_list(mtc_folder_path_with_host_1)).to match_array(host_object_path)
    end

    context "with network manager" do
      let(:ems_openstack) { FactoryBot.create(:ems_openstack) }
      let(:network_manager_folder_path) { "/belongsto/ExtManagementSystem|#{ems_openstack.name} Network Manager" }

      it "converts path with network manager" do
        ems_openstack.update(:name => "XXX")
        expect(belongsto2object_list(network_manager_folder_path)).to match_array([ems_openstack.network_manager])
      end
    end
  end
end
