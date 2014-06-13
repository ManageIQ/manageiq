require "spec_helper"
require Rails.root.join("db/migrate/20130521133700_fix_vm_or_template_alerts.rb")

describe FixVmOrTemplateAlerts do
  migration_context :up do
    let(:tag_stub)     { migration_stub(:Tag) }
    let(:vm_or_template_stub) { migration_stub(:VmOrTemplate) }

    it "migrates v4 alerts" do
      vm = vm_or_template_stub.create!(:guid =>  MiqUUID.new_guid, :vendor => 'vmware', :type => "VmVmware")
      template = vm_or_template_stub.create!(:guid =>  MiqUUID.new_guid, :vendor => 'vmware', :type => "TemplateVmware")
      vm_alert = tag_stub.create!(:name => "/miq_alert_set/assigned_to/vm/id/#{vm.id}")
      template_alert = tag_stub.create!(:name => "/miq_alert_set/assigned_to/vm/id/#{template.id}")
      vm_tag_alert = tag_stub.create!(:name => "/miq_alert_set/assigned_to/vm/tag/managed/testing/yes")
      migrate

      vm_alert.reload.name.should == "/miq_alert_set/assigned_to/vm/id/#{vm.id}"
      template_alert.reload.name.should == "/miq_alert_set/assigned_to/miq_template/id/#{template.id}"
      vm_tag_alert.reload.name.should == "/miq_alert_set/assigned_to/vm/tag/managed/testing/yes"
    end

    it "migrates v5 alerts" do
      vm = vm_or_template_stub.create!(:guid =>  MiqUUID.new_guid, :vendor => 'vmware', :type => "VmVmware")
      template = vm_or_template_stub.create!(:guid =>  MiqUUID.new_guid, :vendor => 'vmware', :type => "TemplateVmware")
      vm_alert = tag_stub.create!(:name => "/miq_alert_set/assigned_to/vm_or_template/id/#{vm.id}")
      template_alert = tag_stub.create!(:name => "/miq_alert_set/assigned_to/vm_or_template/id/#{template.id}")
      vm_tag_alert = tag_stub.create!(:name => "/miq_alert_set/assigned_to/vm_or_template/tag/managed/testing/yes")
      migrate

      vm_alert.reload.name.should == "/miq_alert_set/assigned_to/vm/id/#{vm.id}"
      template_alert.reload.name.should == "/miq_alert_set/assigned_to/miq_template/id/#{template.id}"
      vm_tag_alert.reload.name.should == "/miq_alert_set/assigned_to/vm/tag/managed/testing/yes"
    end
  end

end
