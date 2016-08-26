require "appliance_console/prompts"
require "appliance_console/database_replication"
require "tempfile"

describe ApplianceConsole::DatabaseReplication do
  SPEC_NAME = File.basename(__FILE__).split(".rb").first.freeze

  before do
    allow(subject).to receive(:say)
    allow(subject).to receive(:clear_screen)
    allow(subject).to receive(:agree)
    allow(subject).to receive(:ask_for_ip_or_hostname)
    allow(subject).to receive(:ask_for_password_or_none)
    allow(subject).to receive(:ask_for_password)
  end

  context "#ask_for_unique_cluster_node_number" do
    it "should ask for a unique number" do
      expect(subject).to receive(:ask_for_integer).with(/uniquely identifying this node/i).and_return(1)
      subject.ask_for_unique_cluster_node_number
      expect(subject.node_number).to eq(1)
    end
  end

  context "#ask_for_database_credentials" do
    before do
      subject.database_name     = "defaultdatabasename"
      subject.database_user     = "defaultuser"
      subject.database_password = nil
      subject.primary_host      = "defaultprimary"
    end

    it "should store the newly supplied values" do
      expect(subject).to receive(:just_ask).with(/ name/i, "defaultdatabasename").and_return("newdatabasename")
      expect(subject).to receive(:just_ask).with(/ user/i, "defaultuser").and_return("newuser")
      expect(subject).to receive(:ask_for_password_or_none).with(/password/i, nil).and_return("newpassword")
      expect(subject).to receive(:ask_for_password).with(/password/i).and_return("newpassword")
      expect(subject)
        .to receive(:ask_for_ip_or_hostname).with(/primary.*hostname/i, "defaultprimary").and_return("newprimary")

      subject.ask_for_database_credentials

      expect(subject.database_name).to eq("newdatabasename")
      expect(subject.database_user).to eq("newuser")
      expect(subject.database_password).to eq("newpassword")
      expect(subject.primary_host).to eq("newprimary")
    end
  end

  context "#confirm_reconfiguration" do
    it "should log a warning and ask to continue anyway" do
      expect(subject).to receive(:say).with(/^warning/i)
      expect(subject).to receive(:agree).with(/^continue/i)

      subject.confirm_reconfiguration
    end
  end

  context "#create_config_file" do
    before do
      subject.cluster_name      = "clustername"
      subject.node_number       = "nodenumber"
      subject.database_name     = "databasename"
      subject.database_user     = "user"

      @temp_file = Tempfile.new(subject.class.name.split("::").last.downcase)
      stub_const("ApplianceConsole::DatabaseReplication::REPMGR_CONFIG", @temp_file.path)
    end

    after do
      @temp_file.close
      @temp_file.unlink
    end

    it "should correctly populate the config file" do
      expected_config_file = "cluster=clustername\n"
      expected_config_file << "node=nodenumber\n"
      expected_config_file << "node_name=host\n"
      expected_config_file << "conninfo='host=host user=user dbname=databasename'\n"
      expected_config_file << "use_replication_slots=1\n"
      expected_config_file << "pg_basebackup_options='--xlog-method=stream'\n"

      subject.create_config_file("host")

      expect(File.read(@temp_file.path)).to eq(expected_config_file)
    end

    it "should overwrite an existing config file" do
      expected_config_file = "cluster=clustername\n"
      expected_config_file << "node=nodenumber\n"
      expected_config_file << "node_name=differenthostname\n"
      expected_config_file << "conninfo='host=differenthostname user=user dbname=databasename'\n"
      expected_config_file << "use_replication_slots=1\n"
      expected_config_file << "pg_basebackup_options='--xlog-method=stream'\n"

      subject.create_config_file("host")
      subject.create_config_file("differenthostname")

      expect(File.read(@temp_file.path)).to eq(expected_config_file)
    end
  end

  context "#generate_cluster_name" do
    it "should generate a cluster name and return true" do
      expect(PG::Connection)
        .to receive(:new)
        .and_return(double(SPEC_NAME, :exec => double(SPEC_NAME, :first => { "last_value" => "1_000_000_000_001" })))
      expect(subject.generate_cluster_name).to be_truthy
      expect(subject.cluster_name).to eq("miq_region_1_cluster")
    end

    it "should log an error on connection failures and return false" do
      expect(PG::Connection).to receive(:new).and_raise(PG::ConnectionBad)
      expect(subject).to receive(:say).with(/^failed/i)
      expect(subject.generate_cluster_name).to be_falsey
    end
  end
end
