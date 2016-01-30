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
end
