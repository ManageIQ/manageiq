describe MiqFilter do
  let(:ems)             { FactoryGirl.create(:ems_vmware, :name => 'ems') }
  let(:ems_folder_path) { "/belongsto/ExtManagementSystem|#{ems.name}" }
  let(:datacenter)      { FactoryGirl.create(:ems_folder, :name => "Datacenters") }
  let(:mtc)             { FactoryGirl.create(:ems_folder, :name => "MTC", :is_datacenter => true) }
  let(:ems_folder_path) { "/belongsto/ExtManagementSystem|#{ems.name}" }
  let(:mtc_folder_path) { "#{ems_folder_path}/EmsFolder|#{datacenter.name}/EmsFolder|#{mtc.name}" }
  let(:host_folder)     { FactoryGirl.create(:ems_folder, :name => "host") }
  let(:host_1)          { FactoryGirl.create(:host_vmware, :name => "Host_1", :ext_management_system => ems) }
  let(:host_2)          { FactoryGirl.create(:host_vmware, :name => "Host_2", :ext_management_system => ems) }
  let(:host_3)          { FactoryGirl.create(:host_vmware, :name => "Host_3") }

  let(:mtc_folder_path_with_host_folder) { "#{mtc_folder_path}/EmsFolder|host" }
  let(:mtc_folder_path_with_host_1)      { "#{mtc_folder_path_with_host_folder}/Host|#{host_1.name}" }

  before do
    datacenter.parent = ems
    mtc.parent = datacenter
    host_folder.parent = mtc

    host_1.parent = host_folder
    host_2.parent = host_folder
  end

  describe ".apply_belongsto_filters" do
    it "returns all parent's Host objects when most-specialized filter is the Host object" do
      input_objects = [host_1, host_2]
      results = MiqFilter.apply_belongsto_filters(input_objects, [mtc_folder_path_with_host_1])
      expect(results).to match_array(input_objects)
    end

    it "returns all Host objects when most-specialized filter is Host folder" do
      input_objects = [host_1, host_2]
      results = MiqFilter.apply_belongsto_filters(input_objects, [mtc_folder_path_with_host_folder])
      expect(results).to match_array(input_objects)
    end
  end

  describe ".belongsto2object_list" do
    it "converts belongs_to path to objects" do
      objects_for_folder_path = {}
      objects_for_folder_path[mtc_folder_path] = [ems, datacenter, mtc]
      objects_for_folder_path[mtc_folder_path_with_host_folder] = [ems, datacenter, mtc, host_folder]
      objects_for_folder_path[mtc_folder_path_with_host_1] = [ems, datacenter, mtc, host_folder, host_1]

      objects_for_folder_path.each do |folder, expected_objects|
        results = MiqFilter.belongsto2object_list(folder)
        expect(results).to match_array(expected_objects)
      end
    end
  end
end
