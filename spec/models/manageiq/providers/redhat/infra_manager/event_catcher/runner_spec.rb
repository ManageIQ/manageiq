require "spec_helper"

describe ManageIQ::Providers::Redhat::InfraManager::EventCatcher::Runner do
  context "#event_monitor_options" do
    let(:ems)     { FactoryGirl.create(:ems_redhat, :hostname => "hostname") }
    let(:catcher) { described_class.new(:ems_id => ems.id) }

    before do
      ManageIQ::Providers::Redhat::InfraManager.any_instance.stub(:authentication_check => [true, ""])
      MiqWorker::Runner.any_instance.stub(:worker_initialization)
    end

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
