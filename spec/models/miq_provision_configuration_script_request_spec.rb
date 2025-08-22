describe MiqProvisionConfigurationScriptRequest do
  let(:admin)                { FactoryBot.create(:user) }
  let(:ems)                  { FactoryBot.create(:ems_terraform_enterprise) }
  let(:configuration_script) { FactoryBot.create(:configuration_script_terraform_enterprise, :manager => ems) }
  let(:request)              { FactoryBot.create(:miq_provision_configuration_script_request, :requester => admin, :options => {:src_configuration_script_ids => [configuration_script.id]}) }

  describe ".request_task_class_from" do
    it "retrieves the request task class" do
      options = {:src_configuration_script_ids => configuration_script.id}

      expect(described_class.request_task_class_from("options" => options)).to eq(ems.class::Provision)
    end
  end

  describe ".new_request_task" do
    it "returns the provision task" do
      options = {:src_configuration_script_ids => configuration_script.id}

      request_task = described_class.new_request_task("options" => options)
      pp request_task
    end
  end
end
