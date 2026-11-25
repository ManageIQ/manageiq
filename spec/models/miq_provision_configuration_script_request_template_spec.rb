describe MiqProvisionConfigurationScriptRequestTemplate do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:manager) { FactoryBot.create(:provider_embedded_ansible, :default_organization => 1).managers.first }
  let(:playbook1) { FactoryBot.create(:embedded_ansible_configuration_script, :manager => manager, :name => "Playbook 1") }
  let(:playbook2) { FactoryBot.create(:embedded_ansible_configuration_script, :manager => manager, :name => "Playbook 2") }
  let(:request_template) do
    FactoryBot.create(
      :miq_provision_configuration_script_request_template,
      :requester => user,
      :source    => playbook1,
      :options   => {:src_configuration_script_id => playbook1.id}
    )
  end

  before do
    EvmSpecHelper.assign_embedded_ansible_role
  end

  describe "#sync_source_from_options" do
    context "when options[:src_configuration_script_id] is updated" do
      it "updates source_id to match" do
        expect(request_template.source_id).to eq(playbook1.id)

        request_template.options[:src_configuration_script_id] = playbook2.id
        request_template.save!

        expect(request_template.source_id).to eq(playbook2.id)
        expect(request_template.source).to eq(playbook2)
      end

      it "handles array format for src_configuration_script_id" do
        expect(request_template.source_id).to eq(playbook1.id)

        request_template.options[:src_configuration_script_id] = [playbook2.id]
        request_template.save!

        expect(request_template.source_id).to eq(playbook2.id)
        expect(request_template.source).to eq(playbook2)
      end

      it "does not update source_id if src_configuration_script_id is not present" do
        original_source_id = request_template.source_id

        request_template.options.delete(:src_configuration_script_id)
        request_template.save!

        expect(request_template.source_id).to eq(original_source_id)
      end

      it "does not update source_id if it already matches" do
        expect(request_template.source_id).to eq(playbook1.id)

        # Spy on the source_id= method to ensure it's not called unnecessarily
        allow(request_template).to receive(:source_id=).and_call_original

        request_template.options[:src_configuration_script_id] = playbook1.id
        request_template.save!

        expect(request_template).not_to have_received(:source_id=)
        expect(request_template.source_id).to eq(playbook1.id)
      end
    end

    context "when updating via service catalog item" do
      let(:service_template) do
        FactoryBot.create(
          :service_template_embedded_ansible,
          :name => "Test Service"
        )
      end

      before do
        service_template.add_resource!(request_template)
      end

      it "syncs source when service template config_info is updated" do
        expect(request_template.source_id).to eq(playbook1.id)

        # Simulate what happens when a service catalog item is edited
        request_template.update!(
          :options => request_template.options.merge(:src_configuration_script_id => playbook2.id)
        )

        expect(request_template.reload.source_id).to eq(playbook2.id)
        expect(request_template.source).to eq(playbook2)
      end
    end
  end

  describe "TASK_DESCRIPTION" do
    it "inherits from parent class" do
      expect(described_class::TASK_DESCRIPTION).to eq("Automation Manager Provisioning")
    end
  end

  describe "#execute" do
    it "raises an error as templates should not be executed" do
      expect { request_template.execute }.to raise_error(RuntimeError, /do not support the execute method/)
    end
  end

  describe "#service_template_resource_copy" do
    it "creates a duplicate of the request template" do
      copy = request_template.service_template_resource_copy

      expect(copy).to be_a(MiqProvisionConfigurationScriptRequestTemplate)
      expect(copy.id).not_to eq(request_template.id)
      expect(copy.source_id).to eq(request_template.source_id)
      expect(copy.options).to eq(request_template.options)
    end
  end
end
