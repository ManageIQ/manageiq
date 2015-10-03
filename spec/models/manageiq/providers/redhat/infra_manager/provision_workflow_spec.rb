require "spec_helper"

describe ManageIQ::Providers::Redhat::InfraManager::ProvisionWorkflow do
  include WorkflowSpecHelper

  let(:admin)    { FactoryGirl.create(:user_with_group) }
  let(:ems)      { FactoryGirl.create(:ems_redhat) }
  let(:template) { FactoryGirl.create(:template_redhat, :ext_management_system => ems) }

  before do
    stub_dialog(:get_dialogs)
    described_class.any_instance.stub(:update_field_visibility)
  end

  it "pass platform attributes to automate" do
    assert_automate_dialog_lookup("infra", "redhat", "get_pre_dialog_name", nil)

    described_class.new({}, admin.userid)
  end

  context "#allowed_storages" do
    let(:workflow) { described_class.new({:src_vm_id => template.id}, admin.userid) }
    let(:host)     { FactoryGirl.create(:host, :ext_management_system => ems) }

    before do
      %w(iso data export data).each do |domain_type|
        host.storages << FactoryGirl.create(:storage, :storage_domain_type => domain_type)
      end
      host.reload
      workflow.stub(:process_filter).and_return(host.storages.to_a)
      workflow.stub(:allowed_hosts_obj).and_return([host])
    end

    it "for ISO and PXE provisioning" do
      result = workflow.allowed_storages
      result.length.should == 2
      result.each { |storage| storage.should be_kind_of(MiqHashStruct) }
      result.each { |storage| storage.storage_domain_type.should == "data" }
    end

    it "for linked-clone provisioning" do
      workflow.stub(:supports_linked_clone?).and_return(true)
      template.storage = Storage.where(:storage_domain_type => "data").first
      template.save

      result = workflow.allowed_storages
      result.length.should == 1
      result.each { |storage| storage.should be_kind_of(MiqHashStruct) }
      result.each { |storage| storage.storage_domain_type.should == "data" }
    end
  end

  context "supports_linked_clone?" do
    let(:workflow) { described_class.new({:src_vm_id => template.id, :linked_clone => true}, admin.userid) }

    it "when supports_native_clone? is true" do
      workflow.stub(:supports_native_clone?).and_return(true)
      workflow.supports_linked_clone?.should be_true
    end

    it "when supports_native_clone? is false " do
      workflow.stub(:supports_native_clone?).and_return(false)
      workflow.supports_linked_clone?.should be_false
    end
  end

  context "#supports_cloud_init?" do
    let(:workflow) { described_class.new({:src_vm_id => template.id}, admin.userid) }

    it "should support cloud-init" do
      workflow.supports_cloud_init?.should == true
    end
  end

  context "#allowed_customization_templates" do
    let(:workflow) { described_class.new({:src_vm_id => template.id}, admin.userid) }

    it "should retrieve cloud-init templates when cloning" do
      options = {'key' => 'value'}
      workflow.stub(:supports_native_clone?).and_return(true)
      workflow.should_receive(:allowed_cloud_init_customization_templates).with(options)
      workflow.allowed_customization_templates(options)
    end

    it "should retrieve ISO/PXE templates when not cloning" do
      # Intercept the call to super
      module SuperAllowedCustomizationTemplates
        def allowed_customization_templates(options)
          super_allowed_customization_templates(options)
        end
      end
      workflow.extend(SuperAllowedCustomizationTemplates)

      options = {'key' => 'value'}
      workflow.stub(:supports_native_clone?).and_return(false)
      workflow.should_receive(:super_allowed_customization_templates).with(options)
      workflow.allowed_customization_templates(options)
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }
    it "creates and update a request" do
      EvmSpecHelper.local_miq_server
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_created",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Provisioning requested by <#{admin.userid}> for Vm:#{template.id}"
      )

      # creates a request
      stub_get_next_vm_name

      # the dialogs populate this
      values.merge!(:src_vm_id => template.id, :vm_tags => [])

      request = workflow.make_request(nil, values, admin.userid) # TODO: nil

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqProvisionRequest)
      expect(request.request_type).to eq("template")
      expect(request.description).to eq("Provision from [#{template.name}] to [New VM]")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      stub_get_next_vm_name

      workflow = described_class.new(values, alt_user.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Provisioning request updated by <#{alt_user.userid}> for Vm:#{template.id}"
      )
      workflow.make_request(request, values, alt_user.userid)
    end
  end
end
