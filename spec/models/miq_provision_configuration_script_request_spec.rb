describe MiqProvisionConfigurationScriptRequest do
  let(:admin)                { FactoryBot.create(:user) }
  let(:ems)                  { FactoryBot.create(:automation_manager, :url => "https://localhost") }
  let(:payload)              { FactoryBot.create(:configuration_script_payload, :manager => ems) }
  let(:configuration_script) { FactoryBot.create(:configuration_script, :manager => ems, :parent => payload) }
  let(:request)              { FactoryBot.create(:miq_provision_configuration_script_request, :requester => admin, :options => {:src_configuration_script_id => [configuration_script.id]}) }

  describe ".request_task_class_from" do
    it "retrieves the request task class" do
      options = {:src_configuration_script_id => configuration_script.id}

      expect(described_class.request_task_class_from("options" => options)).to eq(ems.class::Provision)
    end

    it "raises an exception if the script cannot be found" do
      options = {:src_configuration_script_id => payload.id}

      expect { described_class.request_task_class_from("options" => options) }
        .to raise_error(MiqException::MiqProvisionError, /Unable to find source ConfigurationScript with id/)
    end

    it "raises an exception if the script has no EMS" do
      inactive_script = FactoryBot.create(:configuration_script, :manager => nil)
      options         = {:src_configuration_script_id => inactive_script.id}

      expect { described_class.request_task_class_from("options" => options) }
        .to raise_error(MiqException::MiqProvisionError, /Source ConfigurationScript with id \[\d+\] has no EMS, unable to provision/)
    end
  end

  describe ".new_request_task" do
    it "returns the provision task" do
      options = {:src_configuration_script_id => configuration_script.id}

      request_task = described_class.new_request_task("options" => options)
      expect(request_task).to have_attributes(:options => options, :state => "pending")
      expect(request_task).to be_kind_of(ManageIQ::Providers::AutomationManager::Provision)
    end
  end
end
