require "spec_helper"
require Rails.root.join("db/migrate/20120126211839_add_type_to_vms.rb")

describe AddTypeToVms do
  migration_context :up do
    let(:vm)      { migration_stub(:Vm) }

    it "Setting type for hosts" do
      vmware_vm             = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'vmware')
      vmware_template_vm    = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'vmware')
      microsoft_vm          = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'microsoft')
      microsoft_template_vm = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'microsoft')
      xen_vm                = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'xen')
      xen_template_vm       = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'xen')
      kvm_vm                = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'kvm')
      kvm_template_vm       = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'kvm')
      qemu_vm               = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'qemu')
      qemu_template_vm      = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'qemu')
      parallels_vm          = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'parallels')
      parallels_template_vm = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'parallels')
      amazon_vm             = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'amazon')
      amazon_template_vm    = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'amazon')
      redhat_vm             = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'redhat')
      redhat_template_vm    = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'redhat')
      openstack_vm          = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'openstack')
      openstack_template_vm = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'openstack')
      unknown_vm            = vm.create!(:guid =>  MiqUUID.new_guid, :template => false, :vendor => 'unknown')
      unknown_template_vm   = vm.create!(:guid =>  MiqUUID.new_guid, :template => true, :vendor => 'unknown')

      migrate

      vmware_vm.reload.type.should             == "VmVmware"
      vmware_template_vm.reload.type.should    == "TemplateVmware"
      microsoft_vm.reload.type.should          == "VmMicrosoft"
      microsoft_template_vm.reload.type.should == "TemplateMicrosoft"
      xen_vm.reload.type.should                == "VmXen"
      xen_template_vm.reload.type.should       == "TemplateXen"
      kvm_vm.reload.type.should                == "VmKvm"
      kvm_template_vm.reload.type.should       == "TemplateKvm"
      qemu_vm.reload.type.should               == "VmQemu"
      qemu_template_vm.reload.type.should      == "TemplateQemu"
      parallels_vm.reload.type.should          == "VmParallel"
      parallels_template_vm.reload.type.should == "TemplateParallel"
      amazon_vm.reload.type.should             == "VmAmazon"
      amazon_template_vm.reload.type.should    == "TemplateAmazon"
      redhat_vm.reload.type.should             == "VmRedhat"
      redhat_template_vm.reload.type.should    == "TemplateRedhat"
      openstack_vm.reload.type.should          == "VmOpenstack"
      openstack_template_vm.reload.type.should == "TemplateOpenstack"
      unknown_vm.reload.type.should            == "VmUnknown"
      unknown_template_vm.reload.type.should   == "TemplateUnknown"
    end
  end
end
