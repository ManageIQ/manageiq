describe MiqProvisionConfigurationScriptRequest do
  let(:admin)                { FactoryBot.create(:user) }
  let(:ems)                  { FactoryBot.create(:automation_manager, :url => "https://localhost") }
  let(:configuration_script) { FactoryBot.create(:configuration_script, :manager => ems) }
  let(:request)              { FactoryBot.create(:miq_provision_configuration_script_request, :requester => admin, :options => {:source_id => [configuration_script.id]}) }

  describe ".request_task_class_from" do
    it "retrieves the request task class" do
      options = {:source_id => configuration_script.id}

      expect(described_class.request_task_class_from("options" => options)).to eq(ems.class::Provision)
    end
  end

  describe ".new_request_task" do
    it "returns the provision task" do
      options = {:source_id => configuration_script.id}

      request_task = described_class.new_request_task("options" => options)
      expect(request_task).to have_attributes(:options => options, :state => "pending")
      expect(request_task).to be_kind_of(ManageIQ::Providers::AutomationManager::Provision)
    end
  end
end
