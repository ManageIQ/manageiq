require "appliance_console/prompts"
require "appliance_console/database_replication"
require "appliance_console/database_replication_standby"
require "linux_admin"
require "pathname"

describe ApplianceConsole::DatabaseReplicationStandby do
  SPEC_NAME = File.basename(__FILE__).split(".rb").first.freeze

  before do
    allow(ENV).to receive(:fetch).and_return("/test/postgres/directory")
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
      expect(subject).to receive(:ask_for_standby_host)
      expect(subject).to receive(:repmgr_configured?).and_return(false)
      expect(subject).to_not receive(:confirm_reconfiguration)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to be true
    end

    it "returns true when confirm_reconfigure and input is confirmed" do
      expect(subject).to receive(:ask_for_unique_cluster_node_number)
      expect(subject).to receive(:ask_for_database_credentials)
      expect(subject).to receive(:ask_for_standby_host)
      expect(subject).to receive(:repmgr_configured?).and_return(true)
      expect(subject).to receive(:confirm_reconfiguration).and_return(true)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to be true
    end

    it "returns false when confirm_reconfigure is canceled" do
      expect(subject).to receive(:ask_for_unique_cluster_node_number)
      expect(subject).to receive(:ask_for_database_credentials)
      expect(subject).to receive(:ask_for_standby_host)
      expect(subject).to receive(:repmgr_configured?).and_return(true)
      expect(subject).to receive(:confirm_reconfiguration).and_return(false)
      expect(subject).to_not receive(:confirm)
      expect(subject.ask_questions).to be false
    end

    it "returns false when input is not confirmed" do
      expect(subject).to receive(:ask_for_unique_cluster_node_number)
      expect(subject).to receive(:ask_for_database_credentials)
      expect(subject).to receive(:ask_for_standby_host)
      expect(subject).to receive(:repmgr_configured?).and_return(false)
      expect(subject).to_not receive(:confirm_reconfiguration)
      expect(subject).to receive(:confirm).and_return(false)
      expect(subject.ask_questions).to be false
    end
  end

  context "#activate" do
    it "returns true when configure succeed" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:clone_standby_server).and_return(true)
      expect(subject).to receive(:start_postgres).and_return(true)
      expect(subject).to receive(:register_standby_server).and_return(true)
      expect(subject.activate).to be true
    end

    it "returns false when data_dir_empty? fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(false)
      expect(subject).to_not receive(:generate_cluster_name)
      expect(subject).to_not receive(:create_config_file)
      expect(subject).to_not receive(:clone_standby_server)
      expect(subject).to_not receive(:start_postgres)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject.activate).to be false
    end

    it "returns false when generate_cluster_name fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(false)
      expect(subject).to_not receive(:create_config_file)
      expect(subject).to_not receive(:clone_standby_server)
      expect(subject).to_not receive(:start_postgres)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject.activate).to be false
    end

    it "returns false when create_config_file fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(false)
      expect(subject).to_not receive(:clone_standby_server)
      expect(subject).to_not receive(:start_postgres)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject.activate).to be false
    end

    it "returns false when clone_standby_server fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:clone_standby_server).and_return(false)
      expect(subject).to_not receive(:start_postgres)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject.activate).to be false
    end

    it "returns false when start_postgres fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:clone_standby_server).and_return(true)
      expect(subject).to receive(:start_postgres).and_return(false)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject.activate).to be false
    end

    it "returns false when register_standby_server fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:clone_standby_server).and_return(true)
      expect(subject).to receive(:start_postgres).and_return(true)
      expect(subject).to receive(:register_standby_server).and_return(false)
      expect(subject.activate).to be false
    end
  end

  context "create standby server" do
    before do
      allow(Process::UID).to receive(:change_privilege)
      allow(Process::UID).to receive(:from_name)

      expect(subject).to receive(:fork) do |&block|
        block.call
        1234 # return a test pid
      end
    end

    context "#clone_standby_server" do
      it "raises an error when REGISTER_CMD fails" do
        result = double(SPEC_NAME, :output => "", :error => "")
        allow(AwesomeSpawn).to receive(:run!).and_raise(AwesomeSpawn::CommandResultError.new("", result))
        expect { subject.clone_standby_server }.to raise_error(AwesomeSpawn::CommandResultError)
      end
    end

    context "#register_standby_server" do
      it "raises an error when REGISTER_CMD fails" do
        result = double(SPEC_NAME, :output => "", :error => "")
        allow(AwesomeSpawn).to receive(:run!).and_raise(AwesomeSpawn::CommandResultError.new("", result))
        expect { subject.register_standby_server }.to raise_error(AwesomeSpawn::CommandResultError)
      end

      it "Succeed when REGISTER_CMD succeeds" do
        expect(Process).to receive(:wait).with(1234)
        stub_const("ApplianceConsole::DatabaseReplicationStandby::REGISTER_CMD", "pwd")
        expect(subject.register_standby_server).to be true
      end
    end
  end

  context "#ask_for_standby_host" do
    it "should use default prompts" do
      subject.standby_host = "defaultstandby"
      expect(subject)
        .to receive(:ask_for_ip_or_hostname).with(/^standby.*hostname/i, "defaultstandby").and_return("newstandby")
      expect(subject.ask_for_standby_host).to eq("newstandby")
    end
  end

  context "#data_dir_empty?" do
    it "should log a message and return false when not empty" do
      Dir.mktmpdir do |dir|
        open("#{dir}/this_directory_is_not_empty", "w")
        expect(subject).to receive(:say).with(/^Appliance/i)
        expect(PostgresAdmin).to receive(:data_directory).exactly(3).times.and_return(Pathname.new(dir))
        expect(subject.data_dir_empty?).to be_falsey
      end
    end

    it "should quietly return true when empty" do
      Dir.mktmpdir do |dir|
        expect(subject).to_not receive(:say)
        expect(PostgresAdmin).to receive(:data_directory).once.and_return(Pathname.new(dir))
        expect(subject.data_dir_empty?).to be_truthy
      end
    end
  end

  context "#start_postgres" do
    it "should start postgres and return true" do
      service = double(SPEC_NAME, :service => nil)
      expect(LinuxAdmin::Service).to receive(:new).and_return(service)
      expect(service).to receive(:enable).and_return(service)
      expect(service).to receive(:start).and_return(service)
      expect(subject.start_postgres).to be_truthy
    end
  end
end
