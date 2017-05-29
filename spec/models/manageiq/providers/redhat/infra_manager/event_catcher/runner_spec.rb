describe ManageIQ::Providers::Redhat::InfraManager::EventCatcher::Runner do
  context "#event_monitor_options" do
    let(:ems)     { FactoryGirl.create(:ems_redhat, :hostname => "hostname") }
    let(:catcher) { ems.ovirt_services.event_fetcher }

    before do
      allow_any_instance_of(ManageIQ::Providers::Redhat::InfraManager).to receive_messages(:authentication_check => [true, ""])
      allow_any_instance_of(MiqWorker::Runner).to receive(:worker_initialization)
      stub_settings_merge(:ems => { :ems_redhat => { :use_ovirt_engine_sdk => use_ovirt_engine_sdk } })
      allow(ems).to receive(:supported_api_versions) { %w(3 4) }
    end

    context "api version 3" do
      let(:use_ovirt_engine_sdk) { false }
      it "numeric port" do
        ems.update_attributes(:port => 123)
        expect(catcher.event_monitor_options).to have_attributes(:port => 123)
      end

      it "nil port" do
        ems.update_attributes(:port => nil)
        expect(catcher.event_monitor_options).to have_attributes(:port => nil)
      end
    end
  end
end
