require "spec_helper"
require Rails.root.join("db/migrate/20110805164836_add_type_to_hosts.rb")

describe AddTypeToHosts do
  migration_context :up do
    let(:host)      { migration_stub(:Host) }

    it "Setting type for hosts" do
      esx_host          = host.create!(:vmm_vendor => "VMWare", :vmm_product => 'ESX',   :guid =>  MiqUUID.new_guid)
      esxi_host         = host.create!(:vmm_vendor => "VMWare", :vmm_product => 'ESXI',  :guid =>  MiqUUID.new_guid)
      other_vmware_host = host.create!(:vmm_vendor => "VMWare", :vmm_product => 'other', :guid =>  MiqUUID.new_guid)
      microsoft_host    = host.create!(:vmm_vendor => "microsoft",                       :guid =>  MiqUUID.new_guid)
      kvm_host          = host.create!(:vmm_vendor => "kvm",                             :guid =>  MiqUUID.new_guid)
      ec2_host          = host.create!(:vmm_vendor => "ec2",                             :guid =>  MiqUUID.new_guid)
      unknown_host      = host.create!(:vmm_vendor => "something_else",                  :guid =>  MiqUUID.new_guid)

      migrate

      esx_host.reload.type.should         == 'HostVmwareEsx'
      esxi_host.reload.type.should        == 'HostVmwareEsx'
      other_vmware_host.reload.type.should   be_nil
      microsoft_host.reload.type.should   == "HostMicrosoft"
      kvm_host.reload.type.should         == "HostKvm"
      ec2_host.reload.type.should         == "HostAmazon"
      unknown_host.reload.type.should        be_nil
    end
  end
end
