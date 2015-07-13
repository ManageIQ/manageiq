require "spec_helper"
require Rails.root.join("db/migrate/20121121173839_change_port_in_rhevm30_instances.rb")

describe ChangePortInRhevm30Instances do
  migration_context :up do
    let(:ext_management_system_stub)  { migration_stub(:ExtManagementSystem) }

    it "updates rhevm EMS with nil api_version to use v3.0 port" do
      rhevm = ext_management_system_stub.create!(:type => "EmsRedhat", :port => nil, :api_version => nil)

      migrate

      rhevm.reload.port.should eq "8443"
    end

    it "updates rhevm EMS with 3.0 api_version to use v3.0 port" do
      rhevm = ext_management_system_stub.create!(:type => "EmsRedhat", :port => nil, :api_version => "3.0.0.0")

      migrate

      rhevm.reload.port.should eq "8443"
    end

    it "doesn't modify any rhevm EMS with api verion outside 3.0" do
      rhevm = ext_management_system_stub.create!(:type => "EmsRedhat", :port => nil, :api_version => "3.1.0.0")

      migrate

      rhevm.reload.port.should be_nil
    end

    it "doesn't modify any non-rhevm EMS" do
      vmware = ext_management_system_stub.create!(:type => "EmsVmware", :port => nil)

      migrate

      vmware.reload.port.should be_nil
    end
  end
end
