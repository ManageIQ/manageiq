require 'appliance_console/prompts'
require 'appliance_console/database_configuration'
require 'appliance_console/database_replication'
require 'appliance_console/database_replication_primary'
require 'linux_admin'
require 'pg'

describe ApplianceConsole::DatabaseReplicationPrimary do
  SPEC_NAME = File.basename(__FILE__).split(".rb").first.freeze

  before do
    stub_const("ApplianceConsole::NETWORK_INTERFACE", "either_net")
    expect(LinuxAdmin::NetworkInterface).to receive(:new).and_return(double(SPEC_NAME, :address => "192.0.2.1"))
    allow(subject).to receive(:say)
    allow(subject).to receive(:clear_screen)
    allow(subject).to receive(:agree)
    allow(subject).to receive(:just_ask)
    allow(subject).to receive(:ask_for_ip_or_hostname)
    allow(subject).to receive(:ask_for_password_or_none)
  end

  context "#ask_questions" do
    before do
      allow(PG::Connection).to receive(:new).and_return(double(SPEC_NAME, :exec => double(SPEC_NAME, :first => "1")))
    end

    it "returns true when input is confirmed" do
      expect(subject).to receive(:ask_for_unique_cluster_node_number)
      expect(subject).to receive(:ask_for_database_credentials)
      expect(subject).to receive(:repmgr_configured?).and_return(false)
      expect(subject).to_not receive(:confirm_reconfiguration)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to be true
    end

    it "returns true when confirm_reconfigure and input is confirmed" do
      expect(subject).to receive(:ask_for_unique_cluster_node_number)
      expect(subject).to receive(:ask_for_database_credentials)
      expect(subject).to receive(:repmgr_configured?).and_return(true)
      expect(subject).to receive(:confirm_reconfiguration).and_return(true)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to be true
    end

    it "returns false when confirm_reconfigure is canceled" do
      expect(subject).to receive(:ask_for_unique_cluster_node_number)
      expect(subject).to receive(:ask_for_database_credentials)
      expect(subject).to receive(:repmgr_configured?).and_return(true)
      expect(subject).to receive(:confirm_reconfiguration).and_return(false)
      expect(subject).to_not receive(:confirm)
      expect(subject.ask_questions).to be false
    end

    it "returns false when input is not confirmed" do
      expect(subject).to receive(:ask_for_unique_cluster_node_number)
      expect(subject).to receive(:ask_for_database_credentials)
      expect(subject).to receive(:repmgr_configured?).and_return(false)
      expect(subject).to_not receive(:confirm_reconfiguration)
      expect(subject).to receive(:confirm).and_return(false)
      expect(subject.ask_questions).to be false
    end
  end

  context "#activate" do
    it "returns true when configure succeed" do
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:initialize_primary_server).and_return(true)
      expect(subject.activate).to be true
    end

    it "returns false when create_config_file fails" do
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(false)
      expect(subject).to_not receive(:initialize_primary_server)
      expect(subject.activate).to be false
    end

    it "returns false when generate_cluster_name fails" do
      expect(subject).to receive(:generate_cluster_name).and_return(false)
      expect(subject).to_not receive(:create_config_file)
      expect(subject).to_not receive(:initialize_primary_server)
      expect(subject.activate).to be false
    end

    it "returns false when initialize_primary_server fails" do
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:initialize_primary_server).and_return(false)
      expect(subject.activate).to be false
    end
  end

  context "#initialize_primary_server" do
    before do
      allow(Process::UID).to receive(:change_privilege)
      allow(Process::UID).to receive(:from_name)

      expect(subject).to receive(:fork) do |&block|
        block.call
        1234 # return a test pid
      end
    end

    it "raises an error when REGISTER_CMD fails" do
      result = double(SPEC_NAME, :output => '', :error => '')
      allow(AwesomeSpawn).to receive(:run!).and_raise(AwesomeSpawn::CommandResultError.new('', result))
      expect { subject.initialize_primary_server }.to raise_error(AwesomeSpawn::CommandResultError)
    end

    it "Succeed when REGISTER_CMD succeeds" do
      expect(Process).to receive(:wait).with(1234)
      stub_const("ApplianceConsole::DatabaseReplicationPrimary::REGISTER_CMD", "pwd")
      expect(subject.initialize_primary_server).to be true
    end
  end
end
