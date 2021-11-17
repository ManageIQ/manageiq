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
        end
      end

      context "#level=" do
        it "updates the log level on all backing devices" do
          expect(subject.level).to eq(Logger::INFO)

          subject.level = Logger::WARN

          expect(subject.level).to eq(Logger::WARN)
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
        expect(container_log.level).to eq(Logger::INFO)
      end
    end
  end

  describe ".contents" do
    it "with no log returns empty string" do
      allow(File).to receive_messages(:file? => false)
      expect(described_class.contents("mylog.log")).to eq("")
    end

    it "with empty log returns empty string" do
      require 'util/miq-system'
      allow(MiqSystem).to receive_messages(:tail => "")

      allow(File).to receive_messages(:file? => true)
      expect(described_class.contents("mylog.log")).to eq("")
    end

    it "with tail returns only those lines" do
      log = File.expand_path(File.join(File.dirname(__FILE__), "data/miq_ascii.log"))

      expect(described_class.contents(log, 2)).to eq("file with only ascii texts3\nfile with only ascii texts4")
    end

    it "with Logger(file)" do
      log = Logger.new(File.expand_path(File.join(File.dirname(__FILE__), "data/miq_ascii.log")))

      expect(described_class.contents(log, 2)).to eq("file with only ascii texts3\nfile with only ascii texts4")
    end

    it "with Logger(IO)" do
      log = Logger.new($stdout)

      expect(described_class.contents(log, 2)).to be_empty
    end

    it "with ManageIQ::Loggers::Base object" do
      log = ManageIQ::Loggers::Base.new(File.expand_path(File.join(File.dirname(__FILE__), "data/miq_ascii.log")))

      expect(described_class.contents(log, 2)).to eq("file with only ascii texts3\nfile with only ascii texts4")
    end

    context "with evm log snippet with invalid utf8 byte sequence data" do
      before(:each) do
        @log = File.expand_path(File.join(File.dirname(__FILE__), "data/redundant_utf8_byte_sequence.log"))
      end

      context "accessing the invalid data directly" do
        before(:each) do
          @data = File.read(@log)
        end

        it "should have content with the invalid utf8 lines" do
          expect(@data).not_to be_nil
          expect(@data.kind_of?(String)).to be_truthy
        end

        it "should unpack raw data as UTF-8 characters and raise ArgumentError" do
          expect { @data.unpack("U*") }.to raise_error(ArgumentError)
        end
      end

      context "with line limit" do
        before(:each) do
          @contents = described_class.contents(@log, 1000)
        end

        it "should have content but without the invalid utf8 lines" do
          expect(@contents).not_to be_nil
          expect(@contents.kind_of?(String)).to be_truthy
        end

        it "should unpack logger contents as UTF-8 characters and raise nothing" do
          expect { @contents.unpack("U*") }.not_to raise_error
        end
      end

      context "without line limit" do
        before(:each) do
          @contents = described_class.contents(@log)
        end

        it "should have content but without the invalid utf8 lines" do
          expect(@contents).not_to be_nil
          expect(@contents.kind_of?(String)).to be_truthy
        end

        it "should unpack logger contents as UTF-8 characters and raise nothing" do
          expect { @contents.unpack("U*") }.not_to raise_error
        end
      end

      context "encoding" do
        it "with ascii file" do
          log = File.expand_path(File.join(File.dirname(__FILE__), "data/miq_ascii.log"))
          expect(described_class.contents(log).encoding.name).to eq("UTF-8")
          expect(described_class.contents(log, nil).encoding.name).to eq("UTF-8")
        end

        it "with utf-8 file" do
          log = File.expand_path(File.join(File.dirname(__FILE__), "data/miq_utf8.log"))
          expect(described_class.contents(log).encoding.name).to eq("UTF-8")
          expect(described_class.contents(log, nil).encoding.name).to eq("UTF-8")
        end
      end
    end
  end
end
