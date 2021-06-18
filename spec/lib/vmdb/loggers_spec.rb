RSpec.describe Vmdb::Loggers do
  let(:log_file) { Rails.root.join("log", "foo.log").to_s }

  def in_container_env(example)
    old_env = ENV.delete('CONTAINER')
    ENV['CONTAINER'] = 'true'

    example.run
  ensure
    ENV['CONTAINER'] = old_env
  end

  describe ".create_logger" do
    shared_examples "has basic logging functionality" do
      subject { described_class.create_logger(log_file) }

      let(:container_log) { subject.instance_variable_get(:@broadcast_logger) }

      before do
        # Hide the container logger output to STDOUT
        allow(container_log.logdev).to receive(:write) if container_log
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
            expect(subject).to       receive(:add).with(1, nil, "test message").and_call_original
            expect(container_log).to receive(:add).with(1, nil, "test message").and_call_original if container_log

            subject.info("test message")
          end

          it "only forwards the message if the severity is correct" do
            expect(subject.logdev).not_to       receive(:write).with("test message")
            expect(container_log.logdev).not_to receive(:write).with("test message") if container_log

            subject.debug("test message")
          end
        end
      end

      context "#level" do
        it "defaults the loggers to their default levels" do
          expect(subject.level).to       eq(Logger::INFO)
          expect(container_log.level).to eq(Logger::DEBUG) if container_log # container_log is always DEBUG
        end
      end

      context "#level=" do
        it "updates the log level on all backing devices" do
          expect(subject.level).to       eq(Logger::INFO)
          expect(container_log.level).to eq(Logger::DEBUG) if container_log # container_log is always DEBUG

          subject.level = Logger::WARN

          expect(subject.level).to       eq(Logger::WARN)
          expect(container_log.level).to eq(Logger::DEBUG) if container_log # container_log is always DEBUG
        end
      end

      context "#<<" do
        it "forwards to the other loggers" do
          expect(subject).to       receive(:<<).with("test message").and_call_original
          expect(container_log).to receive(:<<).with("test message").and_call_original if container_log

          subject << "test message"
        end
      end
    end

    context "in a non-container environment" do
      it "does not have a container logger" do
        expect(container_log).to be_nil
      end

      include_examples "has basic logging functionality"
    end

    context "in a container environment" do
      around { |example| in_container_env(example) }

      it "has a container logger" do
        expect(container_log).to_not be_nil
      end

      include_examples "has basic logging functionality"
    end
  end

  describe ".apply_config_value" do
    before do
      allow($log).to receive(:info)
    end

    it "will update the main lower level logger instance" do
      log = described_class.create_logger(log_file)
      described_class.apply_config_value({:foo => :info}, log, :foo)

      expect(log.level).to eq(Logger::INFO)
    end

    context "in a container environment" do
      around { |example| in_container_env(example) }

      it "will always keep container logger as DEBUG" do
        log = described_class.create_logger(log_file)
        container_log = log.instance_variable_get(:@broadcast_logger)
        described_class.apply_config_value({:foo => :info}, log, :foo)

        expect(log.level).to           eq(Logger::INFO)
        expect(container_log.level).to eq(Logger::DEBUG)
      end
    end
  end
end
