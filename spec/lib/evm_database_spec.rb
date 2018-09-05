require 'manageiq-postgres_ha_admin'

describe EvmDatabase do
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

  context "#seed_primordial" do
    it "populates seeds" do
      described_class::PRIMORDIAL_CLASSES.each { |klass| expect(klass.constantize).to receive(:seed) }
      described_class.seed_primordial
    end
  end

  describe ".find_seedable_model_class_names" do
    it "returns ordered classes first" do
      stub_const("EvmDatabase::ORDERED_CLASSES", %w(a z))
      stub_const("EvmDatabase::RAILS_ENGINE_MODEL_CLASS_NAMES", [])
      expect(described_class).to receive(:find_seedable_model_class_names).and_return(%w(a c z))
      expect(described_class.seedable_model_class_names).to eq(%w(a z c))
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

    it "adds a pglogical config handler for every subscription when our server has the database_operations role" do
      ServerRole.seed
      server.role = "database_operations"
      server.activate_all_roles

      subject.run_failover_monitor(monitor)
      handlers = monitor.config_handlers.map(&:first)

      expect(handlers.count).to eq(3)
      handlers.delete_if { |h| h.kind_of?(ManageIQ::PostgresHaAdmin::RailsConfigHandler) }
      expect(handlers.count).to eq(2)
      expect(%w(sub_id_1 sub_id_2)).to include(handlers.first.subscription)
      expect(%w(sub_id_1 sub_id_2)).to include(handlers.last.subscription)
      expect(handlers.first.subscription).not_to eq(handlers.last.subscription)
    end
  end
end
