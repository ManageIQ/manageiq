require "spec_helper"
require Rails.root.join("db/migrate/20110901140214_add_type_to_ext_management_systems.rb")

describe AddTypeToExtManagementSystems do
  migration_context :up do
    let(:ems)      { migration_stub(:ExtManagementSystem) }

    it "Setting type for ext_managemet_systems" do
      vmware_ems    = ems.create!(:emstype => "VMWareWS", :guid =>  MiqUUID.new_guid)
      microsoft_ems = ems.create!(:emstype => "scvmm",    :guid =>  MiqUUID.new_guid)
      kvm_ems       = ems.create!(:emstype => "KVM",      :guid =>  MiqUUID.new_guid)
      redhat_ems    = ems.create!(:emstype => "RHEVM",    :guid =>  MiqUUID.new_guid)
      amazon_ems    = ems.create!(:emstype => "ec2",      :guid =>  MiqUUID.new_guid)
      unknown_ems   = ems.create!(:emstype => "other",    :guid =>  MiqUUID.new_guid)

      migrate

      vmware_ems.reload.type.should    == 'EmsVmware'
      microsoft_ems.reload.type.should == 'EmsMicrosoft'
      kvm_ems.reload.type.should       == 'EmsKvm'
      redhat_ems.reload.type.should    == 'EmsRedhat'
      amazon_ems.reload.type.should    == 'EmsAmazon'
      unknown_ems.reload.type.should   == 'EmsVmware'
    end
  end
end
