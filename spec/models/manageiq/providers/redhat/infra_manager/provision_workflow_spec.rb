describe ManageIQ::Providers::Redhat::InfraManager::ProvisionWorkflow do
  include Spec::Support::WorkflowHelper

  let(:admin)    { FactoryGirl.create(:user_with_group) }
  let(:ems)      { FactoryGirl.create(:ems_redhat) }
  let(:template) { FactoryGirl.create(:template_redhat, :ext_management_system => ems) }

  before do
    stub_dialog(:get_dialogs)
    allow_any_instance_of(described_class).to receive(:update_field_visibility)
  end

  it "pass platform attributes to automate" do
    assert_automate_dialog_lookup(admin, "infra", "redhat", "get_pre_dialog_name", nil)

    described_class.new({}, admin)
  end

  context "#allowed_storages" do
    let(:workflow) { described_class.new({:src_vm_id => template.id}, admin) }
    let(:host)     { FactoryGirl.create(:host, :ext_management_system => ems) }

    before do
      %w(iso data export data).each do |domain_type|
        host.storages << FactoryGirl.create(:storage, :storage_domain_type => domain_type)
      end
      host.reload
      allow(workflow).to receive(:process_filter).and_return(host.storages.to_a)
      allow(workflow).to receive(:allowed_hosts_obj).and_return([host])
    end

    it "for ISO and PXE provisioning" do
      result = workflow.allowed_storages
      expect(result.length).to eq(2)
      result.each { |storage| expect(storage).to be_kind_of(MiqHashStruct) }
      result.each { |storage| expect(storage.storage_domain_type).to eq("data") }
    end

    it "for linked-clone provisioning" do
      allow(workflow).to receive(:supports_linked_clone?).and_return(true)
      template.storage = Storage.where(:storage_domain_type => "data").first
      template.save

      result = workflow.allowed_storages
      expect(result.length).to eq(1)
      result.each { |storage| expect(storage).to be_kind_of(MiqHashStruct) }
      result.each { |storage| expect(storage.storage_domain_type).to eq("data") }
    end
  end

  context "allowed clusters" do
    let(:workflow) { described_class.new({:src_vm_id => template.id}, admin) }
    let(:datacenter1) { FactoryGirl.create(:ems_folder, :type => "Datacenter") }
    let(:datacenter2) { FactoryGirl.create(:ems_folder, :type => "Datacenter") }
    let(:cluster1) { FactoryGirl.create(:ems_cluster, :ems_id => ems.id, :name => 'Cluster1') }
    let(:cluster2) { FactoryGirl.create(:ems_cluster, :ems_id => ems.id, :name => 'Cluster2') }
    let(:cluster3) { FactoryGirl.create(:ems_cluster, :ems_id => ems.id, :name => 'Cluster3') }
    let(:rp1) { FactoryGirl.create(:resource_pool) }
    let(:rp2) { FactoryGirl.create(:resource_pool) }
    let(:rp3) { FactoryGirl.create(:resource_pool) }
    let(:template) { FactoryGirl.create(:template_redhat, :ext_management_system => ems, :ems_cluster => cluster1) }
    let(:host1) { FactoryGirl.create(:host, :ems_id => ems.id, :ems_cluster => cluster1) }
    let(:host2) { FactoryGirl.create(:host, :ems_id => ems.id, :ems_cluster => cluster2) }
    let(:host3) { FactoryGirl.create(:host, :ems_id => ems.id, :ems_cluster => cluster3) }
    before(:each) do
      allow_any_instance_of(User).to receive(:get_timezone).and_return("UTC")
      allow(workflow).to receive(:get_source_and_targets).and_return(:ems => ems, :vm => template)
      ems.add_child(datacenter1)
      ems.add_child(datacenter2)
      datacenter1.add_child(cluster1)
      datacenter1.add_child(cluster2)
      datacenter2.add_child(cluster3)
      rp1.set_parent(cluster1)
      rp2.set_parent(cluster2)
      rp3.set_parent(cluster3)
      host1.set_parent(rp1)
      host2.set_parent(rp2)
      host3.set_parent(rp3)
    end

    it 'only from same data_center as template' do
      expect(workflow.allowed_clusters).to match_array([[cluster1.id, cluster1.name], [cluster2.id, cluster2.name]])
    end
  end
  context "supports_linked_clone?" do
    let(:workflow) { described_class.new({:src_vm_id => template.id, :linked_clone => true}, admin) }

    it "when supports_native_clone? is true" do
      allow(workflow).to receive(:supports_native_clone?).and_return(true)
      expect(workflow.supports_linked_clone?).to be_truthy
    end

    it "when supports_native_clone? is false " do
      allow(workflow).to receive(:supports_native_clone?).and_return(false)
      expect(workflow.supports_linked_clone?).to be_falsey
    end
  end

  context "#supports_cloud_init?" do
    let(:workflow) { described_class.new({:src_vm_id => template.id}, admin) }

    it "should support cloud-init" do
      expect(workflow.supports_cloud_init?).to eq(true)
    end
  end

  context "#allowed_customization_templates" do
    let(:workflow) { described_class.new({:src_vm_id => template.id}, admin) }

    it "should retrieve cloud-init templates when cloning" do
      options = {'key' => 'value'}
      allow(workflow).to receive(:supports_native_clone?).and_return(true)
      expect(workflow).to receive(:allowed_cloud_init_customization_templates).with(options)
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
      allow(workflow).to receive(:supports_native_clone?).and_return(false)
      expect(workflow).to receive(:super_allowed_customization_templates).with(options)
      workflow.allowed_customization_templates(options)
    end

    it "should retrieve templates in region" do
      template = FactoryGirl.create(:customization_template_cloud_init, :name => "test1")

      my_region_number = template.my_region_number
      other_region_id  = (my_region_number + 1) * template.class.rails_sequence_factor + 1
      pxe_image_type   = FactoryGirl.create(:pxe_image_type, :name => "test_image", :id => other_region_id)
      FactoryGirl.create(:customization_template_cloud_init,
                         :name           => "test2",
                         :id             => other_region_id,
                         :pxe_image_type => pxe_image_type)

      expect(workflow).to receive(:supports_native_clone?).and_return(true)
      result = workflow.allowed_customization_templates
      expect(result.size).to eq(1)
      expect(result.first.id).to eq(template.id)
      expect(result.first.name).to eq(template.name)
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }
    it "creates and update a request" do
      EvmSpecHelper.local_miq_server
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin)

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

      request = workflow.make_request(nil, values)

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqProvisionRequest)
      expect(request.request_type).to eq("template")
      expect(request.description).to eq("Provision from [#{template.name}] to [New VM]")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      stub_get_next_vm_name

      workflow = described_class.new(values, alt_user)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Provisioning request updated by <#{alt_user.userid}> for Vm:#{template.id}"
      )
      workflow.make_request(request, values)
    end
  end
end
