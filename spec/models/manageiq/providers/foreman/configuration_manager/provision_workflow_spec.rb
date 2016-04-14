describe ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionWorkflow do
  include WorkflowSpecHelper

  let(:admin)   { FactoryGirl.create(:user_with_group) }
  let(:manager) { FactoryGirl.create(:configuration_manager_foreman) }
  let(:system)  { FactoryGirl.create(:configured_system_foreman, :manager => manager) }

  it "#allowed_configuration_profiles" do
    cp       = FactoryGirl.build(:configuration_profile, :name => "test profile")
    cs       = FactoryGirl.build(:configured_system_foreman)
    workflow = FactoryGirl.build(:miq_provision_configured_system_foreman_workflow)

    workflow.instance_variable_set(:@values, :src_configured_system_ids => [cs.id])
    expect(ConfiguredSystem).to receive(:common_configuration_profiles_for_selected_configured_systems)
      .with([cs.id])
      .and_return([cp])

    expect(workflow.allowed_configuration_profiles).to eq(cp.id => cp.name)
  end

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }

    it "creates and update a request" do
      EvmSpecHelper.local_miq_server
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)

      workflow = described_class.new(values = {:running_pre_dialog => false}, admin)

      expect(AuditEvent).to receive(:success).with(
        :event        => "configured_system_provision_request_created",
        :target_class => "ConfiguredSystem",
        :userid       => admin.userid,
        :message      => "Configured System Provisioning requested by <#{admin.userid}> for ConfiguredSystem:#{[system.id].inspect}"
      )

      # creates a request

      # the dialogs populate this
      values.merge!(:src_configured_system_ids => [system.id], :vm_tags => [])

      request = workflow.make_request(nil, values)

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqProvisionConfiguredSystemRequest)
      expect(request.request_type).to eq("provision_via_foreman")
      expect(request.description).to eq("Foreman install on [#{system.name}]")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request
      workflow = described_class.new(values, alt_user)

      expect(AuditEvent).to receive(:success).with(
        :event        => "configured_system_provision_request_updated",
        :target_class => "ConfiguredSystem",
        :userid       => alt_user.userid,
        :message      => "Configured System Provisioning request updated by <#{alt_user.userid}> for ConfiguredSystem:#{[system.id].inspect}"
      )
      workflow.make_request(request, values)
    end
  end
end
