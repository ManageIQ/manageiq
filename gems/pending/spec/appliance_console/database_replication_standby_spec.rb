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
    it "returns false immediatly when the data directory is not empty and data resync is not confirmed" do
      with_non_empty_data_directory do
        allow(subject).to receive(:say)
        expect(subject).to receive(:ask_yn?).and_return(false)
        expect(subject.ask_questions).to be false
      end
    end

    context "asks the default questions and" do
      before do
        expect(subject).to receive(:ask_for_unique_cluster_node_number)
        expect(subject).to receive(:ask_for_database_credentials)
        expect(subject).to receive(:ask_for_standby_host)
        expect(subject).to receive(:ask_for_repmgrd_configuration)
        expect(subject).to receive(:ask_for_disk).and_return("/dev/sdd")
      end

      context "with empty data directory" do
        it "returns false when the node number is not valid" do
          with_empty_data_directory do
            expect(subject).to receive(:node_number_valid?).and_return(false)
            expect(subject.ask_questions).to be false
          end
        end

        it "returns true when repmgr is not already configured" do
          with_empty_data_directory do
            expect(subject).to receive(:node_number_valid?).and_return(true)
            expect(subject).to receive(:repmgr_configured?).and_return(false)
            expect(subject).to_not receive(:confirm_reconfiguration)
            expect(subject).to receive(:confirm).and_return(true)
            expect(subject.ask_questions).to be true
          end
        end

        it "sets the disk and returns true when input is confirmed" do
          with_empty_data_directory do
            expect(subject).to receive(:node_number_valid?).and_return(true)
            expect(subject).to receive(:repmgr_configured?).and_return(false)
            expect(subject).to_not receive(:confirm_reconfiguration)
            expect(subject).to receive(:confirm).and_return(true)
            expect(subject.ask_questions).to be true

            expect(subject.disk).to eq("/dev/sdd")
          end
        end

        it "returns true when confirm_reconfigure and input is confirmed" do
          with_empty_data_directory do
            expect(subject).to receive(:node_number_valid?).and_return(true)
            expect(subject).to receive(:repmgr_configured?).and_return(true)
            expect(subject).to receive(:confirm_reconfiguration).and_return(true)
            expect(subject).to receive(:confirm).and_return(true)
            expect(subject.ask_questions).to be true
          end
        end

        it "returns false when confirm_reconfigure is canceled" do
          with_empty_data_directory do
            expect(subject).to receive(:node_number_valid?).and_return(true)
            expect(subject).to receive(:repmgr_configured?).and_return(true)
            expect(subject).to receive(:confirm_reconfiguration).and_return(false)
            expect(subject).to_not receive(:confirm)
            expect(subject.ask_questions).to be false
          end
        end

        it "returns false when input is not confirmed" do
          with_empty_data_directory do
            expect(subject).to receive(:node_number_valid?).and_return(true)
            expect(subject).to receive(:repmgr_configured?).and_return(false)
            expect(subject).to_not receive(:confirm_reconfiguration)
            expect(subject).to receive(:confirm).and_return(false)
            expect(subject.ask_questions).to be false
          end
        end
      end

      context "with non-empty data directory" do
        it "returns true when resync is confirmed" do
          with_non_empty_data_directory do
            allow(subject).to receive(:say)
            expect(subject).to receive(:ask_yn?).and_return(true)
            expect(subject).to receive(:node_number_valid?).and_return(true)
            expect(subject).to receive(:repmgr_configured?).and_return(false)
            expect(subject).to_not receive(:confirm_reconfiguration)
            expect(subject).to receive(:confirm).and_return(true)
            expect(subject.ask_questions).to be true
          end
        end
      end
    end
  end

  context "#activate" do
    before do
      expect(subject).to receive(:stop_postgres)
      expect(subject).to receive(:stop_repmgrd)
      expect(subject).to receive(:generate_cluster_name).and_return(true)
      expect(subject).to receive(:create_config_file).and_return(true)
      expect(subject).to receive(:clone_standby_server).and_return(true)
      expect(subject).to receive(:start_postgres).and_return(true)
      expect(subject).to receive(:register_standby_server).and_return(true)
      expect(subject).to receive(:write_pgpass_file).and_return(true)
    end

    it "cleans the data directory if resync_data is set" do
      subject.run_repmgrd_configuration = false
      subject.resync_data = true
      expect(PostgresAdmin).to receive(:prep_data_directory)
      expect(subject.activate).to be true
    end

    it "returns true when configure succeeds" do
      subject.run_repmgrd_configuration = false
      expect(subject.activate).to be true
    end

    it "runs #start_repmgrd when run_repmgrd_configuration is set" do
      subject.run_repmgrd_configuration = true
      expect(subject).to receive(:start_repmgrd).and_return(true)
      expect(subject.activate).to be true
    end

    it "configures the postgres disk when given a disk" do
      subject.disk = "/dev/sdd"

      lvm = double("ApplianceConsole::LogicalVolumeManagement")
      expect(ApplianceConsole::LogicalVolumeManagement).to receive(:new)
        .with(hash_including(:disk => "/dev/sdd")).and_return(lvm)
      expect(lvm).to receive(:setup)
      expect(PostgresAdmin).to receive(:prep_data_directory)
      expect(subject.activate).to be true
    end

    it "doesn't configure a disk if disk is not set" do
      subject.disk = nil
      expect(ApplianceConsole::LogicalVolumeManagement).not_to receive(:new)
      expect(subject.activate).to be true
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
        subject.database_password = "secret"
        run_args = [
          "repmgr standby register",
          {
            :params => {:force => nil},
            :env    => {"PGPASSWORD" => "secret"}
          }
        ]

        expect(Process).to receive(:wait).with(1234)
        expect(AwesomeSpawn).to receive(:run!).with(*run_args).and_return(double(:output => "success"))
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
    it "should return false when not empty" do
      with_non_empty_data_directory do
        expect(subject.data_dir_empty?).to be_falsey
      end
    end

    it "should return true when empty" do
      with_empty_data_directory do
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

  context "#stop_postgres" do
    it "should stop postgres and return true" do
      service = double("PostgresService", :service => nil)
      expect(LinuxAdmin::Service).to receive(:new).and_return(service)
      expect(service).to receive(:stop)

      expect(subject.stop_postgres).to be_truthy
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

  context "#stop_repmgrd" do
    it "stops the repmgrd service" do
      service = double("RepmgrdService")
      expect(LinuxAdmin::Service).to receive(:new).and_return(service)
      expect(service).to receive(:stop)

      expect(subject.stop_repmgrd).to be true
    end
  end

  context "#node_number_valid?" do
    let(:node_number) { 1 }
    let(:connection)  { double("PG::Connection") }
    let(:type_map)    { double("PG::TypeMap") }

    let(:one_result) do
      data = {
        "type"   => "master",
        "name"   => "my.master.node",
        "active" => true
      }
      mapped_result = double("PG::Result Mapped", :first => data)
      double("PG::Result", :map_types! => mapped_result)
    end

    let(:nil_result) do
      mapped_result = double("nil PG::Result Mapped", :first => nil)
      double("nil PG::Result", :map_types! => mapped_result)
    end

    before do
      expect(PG::Connection).to receive(:new).and_return(connection)
      expect(PG::BasicTypeMapForResults).to receive(:new).and_return(type_map)
      subject.node_number = node_number
    end

    it "returns true if no node is found" do
      expect(connection).to receive(:exec_params).with(instance_of(String), [1]).and_return(nil_result)
      expect(subject.node_number_valid?).to be_truthy
    end

    it "returns true if a node is found and overwrite is confirmed" do
      expect(connection).to receive(:exec_params).with(instance_of(String), [1]).and_return(one_result)
      expect(subject).to receive(:ask_yn?).and_return(true)
      expect(subject.node_number_valid?).to be_truthy
    end

    it "returns false if a node is found and overwrite is not confirmed" do
      expect(connection).to receive(:exec_params).with(instance_of(String), [1]).and_return(one_result)
      expect(subject).to receive(:ask_yn?).and_return(false)
      expect(subject.node_number_valid?).to be_falsey
    end
  end

  def with_empty_data_directory
    Dir.mktmpdir do |dir|
      allow(PostgresAdmin).to receive(:data_directory).and_return(Pathname.new(dir))
      yield
    end
  end

  def with_non_empty_data_directory
    Dir.mktmpdir do |dir|
      open("#{dir}/this_directory_is_not_empty", "w")
      allow(PostgresAdmin).to receive(:data_directory).and_return(Pathname.new(dir))
      yield
    end
  end
end
