describe Vmdb::Loggers do
  let(:log_file) { Rails.root.join("log", "foo.log").to_s }

  def in_container_env(example)
    old_env = ENV.delete('CONTAINER')
    ENV['CONTAINER'] = 'true'
    example.run
  ensure
    # ENV['x'] = nil deletes the key because ENV accepts only string values
    ENV['CONTAINER'] = old_env
  end

  describe "#create_multicast_logger (private)" do
    it "defaults the lower level loggers to `DEBUG`" do
      log = described_class.send(:create_multicast_logger, log_file)

      expect(log.loggers.first.level).to eq(Logger::DEBUG)
      expect(log.loggers.to_a.size).to   eq(1)
    end

    context "in a container environment" do
      around { |example| in_container_env(example) }

      it "sets logger_instance and $container_log to debug" do
        log = described_class.send(:create_multicast_logger, log_file)

        expect(log.loggers.first.level).to     eq(Logger::DEBUG)
        expect(log.loggers.to_a.last.level).to eq(Logger::DEBUG)
      end
    end
  end

  describe "#apply_config_value (private)" do
    it "will update the main lower level logger instance" do
      log = described_class.send(:create_multicast_logger, log_file)
      described_class.send(:apply_config_value, {:foo => :info}, log, :foo)

      expect(log.loggers.first.level).to eq(Logger::INFO)
      expect(log.loggers.to_a.size).to   eq(1)
    end

    context "in a container environment" do
      around { |example| in_container_env(example) }

      it "will always keep $container_log as DEBUG" do
        log = described_class.send(:create_multicast_logger, log_file)
        described_class.send(:apply_config_value, {:foo => :info}, log, :foo)

        expect(log.loggers.first.level).to     eq(Logger::INFO)
        expect(log.loggers.to_a.last.level).to eq(Logger::DEBUG)
      end
    end
  end
end
