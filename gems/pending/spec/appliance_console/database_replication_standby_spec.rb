require "appliance_console/prompts"
require "appliance_console/database_replication"
require "appliance_console/database_replication_standby"
require "linux_admin"
require "pathname"
require "tempfile"

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
      expect(subject).to receive(:ask_for_unique_cluster_node_number)
      expect(subject).to receive(:ask_for_database_credentials)
      expect(subject).to receive(:ask_for_standby_host)
      expect(subject).to receive(:ask_for_repmgrd_configuration)
    end

    it "returns true when input is confirmed" do
      expect(subject).to receive(:repmgr_configured?).and_return(false)
      expect(subject).to_not receive(:confirm_reconfiguration)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to be true
    end

    it "returns true when confirm_reconfigure and input is confirmed" do
      expect(subject).to receive(:repmgr_configured?).and_return(true)
      expect(subject).to receive(:confirm_reconfiguration).and_return(true)
      expect(subject).to receive(:confirm).and_return(true)
      expect(subject.ask_questions).to be true
    end

    it "returns false when confirm_reconfigure is canceled" do
      expect(subject).to receive(:repmgr_configured?).and_return(true)
      expect(subject).to receive(:confirm_reconfiguration).and_return(false)
      expect(subject).to_not receive(:confirm)
      expect(subject.ask_questions).to be false
    end

    it "returns false when input is not confirmed" do
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
      expect(subject).to receive(:configure_repmgrd).and_return(true)
      expect(subject.activate).to be true
    end

    it "returns false when data_dir_empty? fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(false)
      expect(subject).to_not receive(:generate_cluster_name)
      expect(subject).to_not receive(:create_config_file)
      expect(subject).to_not receive(:clone_standby_server)
      expect(subject).to_not receive(:start_postgres)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject).to_not receive(:configure_repmgrd)
      expect(subject.activate).to be false
    end

    it "returns false when generate_cluster_name fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(false)
      expect(subject).to_not receive(:create_config_file)
      expect(subject).to_not receive(:clone_standby_server)
      expect(subject).to_not receive(:start_postgres)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject).to_not receive(:configure_repmgrd)
      expect(subject.activate).to be false
    end

    it "returns false when create_config_file fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(false)
      expect(subject).to_not receive(:clone_standby_server)
      expect(subject).to_not receive(:start_postgres)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject).to_not receive(:configure_repmgrd)
      expect(subject.activate).to be false
    end

    it "returns false when clone_standby_server fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:clone_standby_server).and_return(false)
      expect(subject).to_not receive(:start_postgres)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject).to_not receive(:configure_repmgrd)
      expect(subject.activate).to be false
    end

    it "returns false when start_postgres fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:clone_standby_server).and_return(true)
      expect(subject).to receive(:start_postgres).and_return(false)
      expect(subject).to_not receive(:register_standby_server)
      expect(subject).to_not receive(:configure_repmgrd)
      expect(subject.activate).to be false
    end

    it "returns false when register_standby_server fails" do
      expect(subject).to receive(:data_dir_empty?).and_return(true)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:clone_standby_server).and_return(true)
      expect(subject).to receive(:start_postgres).and_return(true)
      expect(subject).to receive(:register_standby_server).and_return(false)
      expect(subject).to_not receive(:configure_repmgrd)
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

  context "#ask_for_repmgrd_configuration" do
    it "sets the run_repmgrd_configuration attribute" do
      expect(subject).to receive(:ask_yn?).and_return true
      subject.ask_for_repmgrd_configuration
      expect(subject.run_repmgrd_configuration).to be true
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

  context "#configure_repmgrd" do
    it "returns true if not setup to do the configuration" do
      subject.run_repmgrd_configuration = false
      expect(subject.configure_repmgrd).to be true
    end
  end

  context "#write_repmgrd_config" do
    let(:config_path) { Tempfile.new("repmgr_config").path }

    before do
      stub_const("ApplianceConsole::DatabaseReplication::REPMGR_CONFIG", config_path)
    end

    after do
      FileUtils.rm_f(config_path)
    end

    it "appends the correct data to the config file" do
      File.write(config_path, "some other stuff here\n")

      subject.write_repmgrd_config

      expect(File.read(config_path)).to eq(<<-EOS.strip_heredoc)
        some other stuff here
        failover=automatic
        promote_command='repmgr standby promote'
        follow_command='repmgr standby follow'
      EOS
    end
  end

  context "#write_pgpass_file" do
    let(:pgpass_path) { Tempfile.new("pgpass").path }

    before do
      stub_const("#{described_class}::PGPASS_FILE", pgpass_path)
    end

    after do
      FileUtils.rm_f(pgpass_path)
    end

    it "writes the .pgpass file correctly" do
      subject.database_name     = "dbname"
      subject.database_user     = "someuser"
      subject.database_password = "secret"

      expect(FileUtils).to receive(:chown).with("postgres", "postgres", pgpass_path)
      subject.write_pgpass_file

      expect(File.read(pgpass_path)).to eq(<<-EOS.gsub(/^\s+/, ""))
        *:*:dbname:someuser:secret
        *:*:replication:someuser:secret
      EOS

      pgpass_stat = File.stat(pgpass_path)
      expect(pgpass_stat.mode.to_s(8)).to eq("100600")
    end
  end

  context "#start_repmgrd" do
    it "starts and enables repmgrd" do
      service = double(SPEC_NAME)
      expect(LinuxAdmin::Service).to receive(:new).and_return(service)
      expect(service).to receive(:enable).and_return(service)
      expect(service).to receive(:start).and_return(service)
      expect(subject.start_repmgrd).to be true
    end

    it "returns false if the service fails to start" do
      service = double(SPEC_NAME)
      result = double(SPEC_NAME, :output => "", :error => "")
      expect(LinuxAdmin::Service).to receive(:new).and_return(service)
      expect(service).to receive(:enable).and_return(service)
      expect(service).to receive(:start).and_raise(AwesomeSpawn::CommandResultError.new("", result))
      expect(subject.start_repmgrd).to be false
    end
  end
end
