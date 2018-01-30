describe Vmdb::Loggers::MulticastLogger do
  let(:logger1) { Logger.new(StringIO.new) }
  let(:logger2) { Logger.new(StringIO.new) }
  subject { described_class.new(logger1, logger2) }

  context "#add" do
    it "forwards to the other loggers" do
      expect(logger1).to receive(:add).with(1, nil, "test message")
      expect(logger2).to receive(:add).with(1, nil, "test message")

      subject.info("test message")
    end

    it "only forwards the message if the severity is correct" do
      subject.level = 1
      logger1.level = 0

      [logger1, logger2].each { |l| expect(l).not_to receive(:add) }

      subject.debug("test message")
    end
  end

  it "#level= updates the log level on all backing devices" do
    [logger1, logger2, subject].each { |l| expect(l.level).to eq(0) }
    subject.level = 3
    [logger1, logger2, subject].each { |l| expect(l.level).to eq(3) }
  end

  context "#<<" do
    it "forwards to the other loggers" do
      expect(logger1).to receive(:<<).with("test message")
      expect(logger2).to receive(:<<).with("test message")

      subject << "test message"
    end

    it "returns the size of the logged message" do
      expect(subject << "test message").to eql(12)
      expect(subject << "test message   ").to eql(12)
    end
  end
end
