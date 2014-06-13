require "spec_helper"
require Rails.root.join("db/migrate/20130719204831_add_cloud_to_vms.rb")

describe AddCloudToVms do
  migration_context :up do
    let(:vm_or_template_stub) { migration_stub(:VmOrTemplate) }

    it "updates VmCloud with cloud = true" do
      vm_amazon    = vm_or_template_stub.create!(:type => "VmAmazon")
      vm_openstack = vm_or_template_stub.create!(:type => "VmOpenstack")

      migrate

      vm_amazon.reload.cloud.should be_true
      vm_openstack.reload.cloud.should be_true
    end

    it "updates Vminfra with cloud = false" do
      vm_vmware    = vm_or_template_stub.create!(:type => "VmVmware")
      vm_redhat    = vm_or_template_stub.create!(:type => "VmRedhat")
      vm_kvm       = vm_or_template_stub.create!(:type => "VmKvm")
      vm_microsoft = vm_or_template_stub.create!(:type => "VmMicrosoft")
      vm_xen       = vm_or_template_stub.create!(:type => "VmXen")

      migrate

      vm_vmware.reload.cloud.should    be_false
      vm_redhat.reload.cloud.should    be_false
      vm_kvm.reload.cloud.should       be_false
      vm_microsoft.reload.cloud.should be_false
      vm_xen.reload.cloud.should       be_false
    end

    it "updates TemplateCloud with cloud = true" do
      template_amazon    = vm_or_template_stub.create!(:type => "TemplateAmazon")
      template_openstack = vm_or_template_stub.create!(:type => "TemplateOpenstack")

      migrate

      template_amazon.reload.cloud.should be_true
      template_openstack.reload.cloud.should be_true
    end

    it "updates Templateinfra with cloud = false" do
      template_vmware    = vm_or_template_stub.create!(:type => "TemplateVmware")
      template_redhat    = vm_or_template_stub.create!(:type => "TemplateRedhat")
      template_kvm       = vm_or_template_stub.create!(:type => "VmKvm")
      template_microsoft = vm_or_template_stub.create!(:type => "VmMicrosoft")
      template_xen       = vm_or_template_stub.create!(:type => "VmXen")

      migrate

      template_vmware.reload.cloud.should    be_false
      template_redhat.reload.cloud.should    be_false
      template_kvm.reload.cloud.should       be_false
      template_microsoft.reload.cloud.should be_false
      template_xen.reload.cloud.should       be_false
    end
  end
end
