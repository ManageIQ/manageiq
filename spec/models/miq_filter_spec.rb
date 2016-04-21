describe MiqFilter do
  let(:ems)             { FactoryGirl.create(:ems_vmware, :name => 'ems') }
  let(:datacenter)      { FactoryGirl.create(:ems_folder, :name => "Datacenters").tap { |dc| dc.parent = ems } }
  let(:mtc)             { FactoryGirl.create(:datacenter, :name => "MTC").tap { |mtc| mtc.parent = datacenter } }
  let(:ems_folder_path) { "/belongsto/ExtManagementSystem|#{ems.name}" }
  let(:mtc_folder_path) { "#{ems_folder_path}/EmsFolder|#{datacenter.name}/EmsFolder|#{mtc.name}" }
  let(:host_folder)     { FactoryGirl.create(:ems_folder, :name => "host").tap { |hf| hf.parent = mtc } }
  let(:host_1)          { FactoryGirl.create(:host_vmware, :name => "Host_1", :ext_management_system => ems).tap { |h| h.parent = host_folder } }
  let(:host_2)          { FactoryGirl.create(:host_vmware, :name => "Host_2", :ext_management_system => ems).tap { |h| h.parent = host_folder } }
  let(:host_3)          { FactoryGirl.create(:host_vmware, :name => "Host_3") }

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

    it "converts met_folder_path" do
      expect(belongsto2object_list(mtc_folder_path)).to match_array([ems, datacenter, mtc])
    end

    it "converts met_folder with host_folder" do
      host_folder_object_path = [ems, datacenter, mtc, host_folder]
      expect(belongsto2object_list(mtc_folder_path_with_host_folder)).to match_array(host_folder_object_path)
    end

    it "converts met_folder with host_1" do
      host_object_path = [ems, datacenter, mtc, host_folder, host_1]
      expect(belongsto2object_list(mtc_folder_path_with_host_1)).to match_array(host_object_path)
    end
  end
end
