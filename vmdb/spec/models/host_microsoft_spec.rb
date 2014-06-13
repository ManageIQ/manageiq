require "spec_helper"
require 'yaml'
HOST_MICROSOFT_ADD_ELEMENTS_YAML = File.join(File.dirname(__FILE__), '/hyperv_data/hyperv_ems_refresh.yaml')

describe HostMicrosoft do
  let(:host)    {FactoryGirl.create(:host_microsoft, :hostname => "hyperv-h01.manageiq.com")}
  let(:vm)      {FactoryGirl.create(:vm_microsoft)}
  let(:ems)     {FactoryGirl.create(:ems_microsoft)}
  let(:storage) {FactoryGirl.create(:storage)}

  it "import inventory data" do
    data =   YAML.load_file(HOST_MICROSOFT_ADD_ELEMENTS_YAML)
    host.add_elements(data)
    host.vms.count.should == 3
    host.storages.count.should == 2
  end

  context "#orphaned?" do
    context "without storage" do
      it "No EMS but has a host" do
        vm.host = host
        vm.should_not be_orphaned
      end

      it "No host but VM has an EMS" do
        vm.ext_management_system = ems
        vm.should_not be_orphaned
      end

      it "Has a host which has an EMS" do
        host.ext_management_system = ems
        vm.host = host
        vm.should_not be_orphaned
      end

      it "No host and no EMS" do 
        vm.should_not be_orphaned
      end
    end

    context "with storage"  do
      before do
        vm.storage = storage
      end

      it "has no EMS but has a host" do
        vm.host = host
        vm.should_not be_orphaned
      end

      it "has no host but has ems" do
        vm.ext_management_system = ems 
        vm.should_not be_orphaned
      end

      it "with host and the host has an EMS" do
        host.ext_management_system = ems
        vm.host = host
        vm.should be_orphaned
      end

      it "without host and without ems" do 
        vm.should be_orphaned
      end
    end
  end

  context "#archived?" do
    context "without storage" do
      it "has no EMS but has a host" do
        vm.host = host
        vm.should_not be_archived
      end

      it "has no host but has ems" do
        vm.ext_management_system = ems 
        vm.should_not be_archived
      end

      it "has a host and the host has an EMS" do
        host.ext_management_system = ems
        vm.host = host
        vm.should be_archived
      end

      it "has no host and no ems" do 
        vm.should be_archived
      end
    end

    context "with storage"  do
      before do
        vm.storage = storage
      end

      it "has no EMS" do
        vm.host = host
        vm.should_not be_archived
      end

      it "has no host but has ems" do
        vm.ext_management_system = ems
        vm.should_not be_archived
      end

      it "has a host and the host has an EMS" do
        host.ext_management_system = ems
        vm.host = host
        vm.should_not be_archived
      end

      it "has no host and no ems" do
        vm.should_not be_archived
      end
    end
  end
end
