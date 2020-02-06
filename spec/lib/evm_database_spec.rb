require 'manageiq-postgres_ha_admin'

RSpec.describe EvmDatabase do
  subject { described_class }
  context "#local?" do
    ["localhost", "127.0.0.1", "", nil].each do |host|
      it "should know #{host} is local" do
        expect(subject).to receive(:host).at_least(:once).and_return(host)
        expect(subject).to be_local
      end
    end

    it "should know otherhost is not local" do
      expect(subject).to receive(:host).twice.and_return("otherhost")
      expect(subject).not_to be_local
    end
  end

  describe ".seed" do
    it "seeds primordial, non-primordial, and plugin classes by default" do
      described_class.seedable_classes.each do |klass|
        expect(klass.constantize).to receive(:seed)
      end

      described_class.seed
    end

    it "seeds only classes that are given" do
      expect(MiqDatabase).to   receive(:seed)
      expect(MiqRegion).to_not receive(:seed)

      described_class.seed(["MiqDatabase"])
    end

    it "allows exclusion of classes" do
      expect(MiqDatabase).to   receive(:seed)
      expect(MiqRegion).to_not receive(:seed)

      described_class.seed(["MiqDatabase", "MiqRegion"], ["MiqRegion"])
    end

    it "will fail if a class does not respond to .seed" do
      expect { described_class.seed(["VmOrTemplate"]) }.to raise_error(ArgumentError, /do not respond to seed/)
    end

    # this spec takes about 30 seconds but is the only check that db:seed won't fail
    it "doesn't fail" do
      expect do
        described_class.seed
      end.not_to raise_error
    end
  end

  describe ".seed_primordial" do
    it "only seeds primordial classes" do
      described_class::PRIMORDIAL_SEEDABLE_CLASSES.each do |klass|
        expect(klass.constantize).to receive(:seed)
      end
      expect(described_class::OTHER_SEEDABLE_CLASSES.first.constantize).to_not receive(:seed)

      described_class.seed_primordial
    end
  end

  describe ".seed_rest" do
    it "only seeds non-primordial classes" do
      (described_class::OTHER_SEEDABLE_CLASSES + described_class.seedable_plugin_classes).each do |klass|
        expect(klass.constantize).to receive(:seed)
      end
      expect(described_class::PRIMORDIAL_SEEDABLE_CLASSES.first.constantize).to_not receive(:seed)

      described_class.seed_rest
    end
  end

  def simulate_primordial_seed
    described_class.seed(["MiqDatabase", "MiqRegion"])
  end

  def simulate_full_seed
    described_class.seed(["MiqDatabase", "MiqRegion", "MiqAction"])
  end

  describe ".seeded_primordially?" do
    it "when not seeded" do
      expect(EvmDatabase.seeded_primordially?).to be false
    end

    it "when seeded primordially" do
      simulate_primordial_seed
      expect(EvmDatabase.seeded_primordially?).to be true
    end

    it "when fully seeded" do
      simulate_full_seed
      expect(EvmDatabase.seeded_primordially?).to be true
    end
  end

  describe ".seeded?" do
    it "when not seeded" do
      expect(EvmDatabase.seeded?).to be false
    end

    it "when seeded primordially" do
      simulate_primordial_seed
      expect(EvmDatabase.seeded?).to be false
    end

    it "when fully seeded" do
      simulate_full_seed
      expect(EvmDatabase.seeded?).to be true
    end
  end

  describe ".skip_seeding? (private)" do
    it "will not skip when SKIP_SEEDING is not set" do
      expect(ENV).to receive(:[]).with("SKIP_SEEDING").and_return(nil)
      expect(described_class.send(:skip_seeding?)).to be_falsey
    end

    it "will not skip when SKIP_SEEDING is set but the database was never seeded" do
      expect(ENV).to receive(:[]).with("SKIP_SEEDING").and_return("true")
      expect(described_class.send(:skip_seeding?)).to be_falsey
    end

    it "will skip when SKIP_SEEDING is set and the database is seeded" do
      simulate_primordial_seed
      expect(ENV).to receive(:[]).with("SKIP_SEEDING").and_return("true")
      expect(described_class.send(:skip_seeding?)).to be_truthy
    end
  end

  describe ".raise_server_event" do
    it "adds to queue request to raise 'evm_event'" do
      EvmSpecHelper.create_guid_miq_server_zone
      described_class.raise_server_event("db_failover_executed")
      record = MiqQueue.last
      expect(record.class_name). to eq "MiqEvent"
      expect(record.method_name).to eq "raise_evm_event"
      expect(record.args[1]).to eq "db_failover_executed"
    end
  end

  describe ".restart_failover_monitor_service" do
    let(:service) { instance_double(LinuxAdmin::SystemdService) }

    before do
      expect(LinuxAdmin::Service).to receive(:new).and_return(service)
    end

    it "restarts the service when running" do
      expect(service).to receive(:running?).and_return(true)
      expect(service).to receive(:restart)
      described_class.restart_failover_monitor_service
    end

    it "doesn't restart the service when it isn't running" do
      expect(service).to receive(:running?).and_return(false)
      expect(service).not_to receive(:restart)
      described_class.restart_failover_monitor_service
    end
  end

  describe ".restart_failover_monitor_service_queue" do
    it "queues a message for the correct role and zone" do
      subject.restart_failover_monitor_service_queue

      messages = MiqQueue.where(:method_name => 'restart_failover_monitor_service')
      expect(messages.count).to eq(1)

      message = messages.first
      expect(message.class_name).to eq(described_class.name)
      expect(message.role).to eq('database_operations')
      expect(message.zone).to be_nil
    end
  end

  describe ".run_failover_monitor" do
    let!(:server) { EvmSpecHelper.local_guid_miq_server_zone[1] }
    let(:monitor) { ManageIQ::PostgresHaAdmin::FailoverMonitor.new }
    let(:subscriptions) do
      [
        PglogicalSubscription.new(:id => "sub_id_1"),
        PglogicalSubscription.new(:id => "sub_id_2")
      ]
    end

    before do
      allow(PglogicalSubscription).to receive(:all).and_return(subscriptions)
      expect(monitor).to receive(:monitor_loop)
    end

    it "adds a rails handler for the environment in database.yml" do
      subject.run_failover_monitor(monitor)
      handlers = monitor.config_handlers.map(&:first)

      expect(handlers.count).to eq(1)
      h = handlers.first
      expect(h).to be_an_instance_of(ManageIQ::PostgresHaAdmin::RailsConfigHandler)
      expect(h.file_path.to_s.split('/').last).to eq("database.yml")
      expect(h.environment).to eq("test")
    end

    it "adds a logical replication config handler for every subscription when our server has the database_operations role" do
      ServerRole.seed
      server.role = "database_operations"
      server.activate_all_roles

      subject.run_failover_monitor(monitor)
      handlers = monitor.config_handlers.map(&:first)

      expect(handlers.count).to eq(3)
      handlers.select! { |h| h.kind_of?(ManageIQ::PostgresHaAdmin::LogicalReplicationConfigHandler) }
      expect(handlers.count).to eq(2)
      expect(%w(sub_id_1 sub_id_2)).to include(handlers.first.subscription)
      expect(%w(sub_id_1 sub_id_2)).to include(handlers.last.subscription)
      expect(handlers.first.subscription).not_to eq(handlers.last.subscription)
    end
  end
end
