RSpec.describe Vmdb::Loggers do
  let(:log_file) { Rails.root.join("log", "foo.log").to_s }

  def in_container_env(example)
    old_env = ENV.delete('CONTAINER')
    ENV['CONTAINER'] = 'true'
    $container_log = described_class.send(:create_container_logger)

    example.run
  ensure
    # ENV['x'] = nil deletes the key because ENV accepts only string values
    ENV['CONTAINER'] = old_env
    $container_log = nil
  end

  describe "#create_multicast_logger (private)" do
    shared_examples "has basic logging functionality" do
      subject { described_class.send(:create_multicast_logger, log_file) }

      before do
        # Hide the container logger output to STDOUT
        allow($container_log.logdev).to receive(:write) if $container_log
      end

      it "responds to #<<" do
        expect(subject).to respond_to(:<<)
      end

      it "responds to #debug" do
        expect(subject).to respond_to(:debug)
      end

      it "responds to #info" do
        expect(subject).to respond_to(:warn)
      end

      it "responds to #error" do
        expect(subject).to respond_to(:error)
      end

      it "responds to #fatal" do
        expect(subject).to respond_to(:fatal)
      end

      it "responds to #unknown" do
        expect(subject).to respond_to(:unknown)
      end

      describe "#datetime_format" do
        it "return nil" do
          expect(subject.datetime_format).to be nil
        end

        it "does not raise an error" do
          expect { subject.datetime_format }.to_not raise_error
        end
      end

      context "#add" do
        context "for info logger levels" do
          around do |example|
            old_level, subject.level = subject.level, Logger::INFO
            example.run
          ensure
            subject.level = old_level
          end

          it "forwards to the other loggers" do
            expect(subject).to        receive(:add).with(1, nil, "test message").and_call_original
            expect($container_log).to receive(:add).with(1, nil, "test message").and_call_original if $container_log

            subject.info("test message")
          end

          it "only forwards the message if the severity is correct" do
            expect(subject.logdev).not_to        receive(:write).with("test message")
            expect($container_log.logdev).not_to receive(:write).with("test message") if $container_log

            subject.debug("test message")
          end
        end
      end

      context "#level" do
        it "defaults the loggers to their default levels" do
          expect(subject.level).to        eq(Logger::INFO)
          expect($container_log.level).to eq(Logger::DEBUG) if $container_log # $container_log is always DEBUG
        end
      end

      context "#level=" do
        it "updates the log level on all backing devices" do
          expect(subject.level).to        eq(Logger::INFO)
          expect($container_log.level).to eq(Logger::DEBUG) if $container_log # $container_log is always DEBUG

          subject.level = Logger::WARN

          expect(subject.level).to        eq(Logger::WARN)
          expect($container_log.level).to eq(Logger::DEBUG) if $container_log # $container_log is always DEBUG
        end
      end

      context "#<<" do
        it "forwards to the other loggers" do
          expect(subject).to        receive(:<<).with("test message").and_call_original
          expect($container_log).to receive(:<<).with("test message").and_call_original if $container_log

          subject << "test message"
        end
      end
    end

    context "in a non-container environment" do
      include_examples "has basic logging functionality"
    end

    context "in a container environment" do
      around { |example| in_container_env(example) }

      include_examples "has basic logging functionality"
    end
  end

  describe "#apply_config_value (private)" do
    before do
      allow($log).to receive(:info)
    end

    it "will update the main lower level logger instance" do
      log = described_class.send(:create_multicast_logger, log_file)
      described_class.send(:apply_config_value, {:foo => :info}, log, :foo)

      expect(log.level).to eq(Logger::INFO)
    end

    context "in a container environment" do
      around { |example| in_container_env(example) }

      it "will always keep $container_log as DEBUG" do
        log = described_class.send(:create_multicast_logger, log_file)
        described_class.send(:apply_config_value, {:foo => :info}, log, :foo)

        expect(log.level).to            eq(Logger::INFO)
        expect($container_log.level).to eq(Logger::DEBUG)
      end
    end
  end
end
