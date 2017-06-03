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
end
