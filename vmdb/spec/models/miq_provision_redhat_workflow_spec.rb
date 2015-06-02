require "spec_helper"

describe MiqProvisionRedhatWorkflow do
  before do
    MiqRegion.seed
  end

  context "With a Valid Template," do
    let(:admin)    { FactoryGirl.create(:user, :name => 'admin', :userid => 'admin') }
    let(:provider) { FactoryGirl.create(:ems_redhat) }
    let(:template) { FactoryGirl.create(:template_redhat, :name => "template", :ext_management_system => provider) }

    before do
      MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return( {:dialogs => {}} )
      MiqProvisionRedhatWorkflow.any_instance.stub(:update_field_visibility)
    end

    it "pass platform attributes to automate" do
      MiqAeEngine.should_receive(:resolve_automation_object)
      MiqAeEngine.should_receive(:create_automation_object) do |name, attrs, _options|
        name.should eq("REQUEST")
        attrs.should have_attributes(
          'request'                   => 'UI_PROVISION_INFO',
          'message'                   => 'get_pre_dialog_name',
          'dialog_input_request_type' => 'template',
          'dialog_input_target_type'  => 'vm',
          'platform_category'         => 'infra',
          'platform'                  => 'redhat'
        )
      end

      MiqProvisionRedhatWorkflow.new({}, admin.userid)
    end

    context "#allowed_storages" do
      let(:workflow) { MiqProvisionRedhatWorkflow.new({:src_vm_id => template.id}, admin.userid) }
      let(:host)     { FactoryGirl.create(:host, :ext_management_system => provider) }

      before do
        %w{iso data export data}.each do |domain_type|
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
      let(:workflow) { MiqProvisionRedhatWorkflow.new({:src_vm_id => template.id, :linked_clone => true}, admin.userid) }

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
      let(:workflow) { MiqProvisionRedhatWorkflow.new({:src_vm_id => template.id}, admin.userid) }

      it "should support cloud-init" do
        workflow.supports_cloud_init?.should == true
      end
    end

    context "#allowed_customization_templates" do
      let(:workflow) { MiqProvisionRedhatWorkflow.new({:src_vm_id => template.id}, admin.userid) }

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
  end
end
