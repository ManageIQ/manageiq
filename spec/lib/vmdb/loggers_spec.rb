require "stringio"

RSpec.describe Vmdb::Loggers do
  let(:log_file_name) { "#{SecureRandom.alphanumeric}.log" }
  let(:log_file_path) { Rails.root.join("log", log_file_name) }

  after do
    log_file_path.delete if log_file_path.exist?
  end

  def in_appliance_env(example)
    old_env = ENV.delete('APPLIANCE')
    ENV['APPLIANCE'] = 'true'

    example.run
  ensure
    ENV['APPLIANCE'] = old_env
  end

  def in_container_env(example)
    old_env = ENV.delete('CONTAINER')
    ENV['CONTAINER'] = 'true'

    example.run
  ensure
    ENV['CONTAINER'] = old_env
  end

  describe ".create_logger" do
    shared_examples "has basic logging functionality" do
      let(:log_file) { log_file_name }

      subject { described_class.create_logger(log_file) }

      let(:container_log) { subject.try(:wrapped_logger) }

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

      it "#logdev" do
        if container_log
          expect(subject.logdev).to be_nil
        else
          expect(subject.logdev).to be_a Logger::LogDevice
        end
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
            if container_log
              expect(subject.logdev).to           be_nil
              expect(container_log.logdev).not_to receive(:write).with("test message")
            else
              expect(subject.logdev).not_to       receive(:write).with("test message")
            end

            subject.debug("test message")
          end
        end
      end

      context "#level" do
        it "defaults the loggers to their default levels" do
          expect(subject.level).to eq(Logger::INFO)
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

      context "with an IO" do
        let(:log_file) { StringIO.new }

        it "logs correctly" do
          expect(subject).to       receive(:add).with(1, nil, "test message").and_call_original
          expect(container_log).to receive(:add).with(1, nil, "test message").and_call_original if container_log

          subject.info("test message")

          expect(log_file.string).to include("test message") unless container_log
        end
      end

      context "with a Pathname" do
        let(:log_file) { Rails.root.join("tmp/logger_pathname.log") }

        after { log_file.delete if log_file.exist? }

        it "logs correctly" do
          expect(subject).to       receive(:add).with(1, nil, "test message").and_call_original
          expect(container_log).to receive(:add).with(1, nil, "test message").and_call_original if container_log

          subject.info("test message")

          expect(log_file.read).to include("test message") unless container_log
        end
      end

      context "with a full path String" do
        let(:log_file) { Rails.root.join("tmp/logger_string.log").to_s }

        after { File.delete(log_file) if File.exist?(log_file) }

        it "logs correctly" do
          expect(subject).to       receive(:add).with(1, nil, "test message").and_call_original
          expect(container_log).to receive(:add).with(1, nil, "test message").and_call_original if container_log

          subject.info("test message")

          expect(File.read(log_file)).to include("test message") unless container_log
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
    it "will update the main lower level logger instance" do
      log = described_class.create_logger(log_file_name)

      described_class.apply_config_value({:level_foo => :error}, log, :level_foo)

      expect(log.level).to eq(Logger::ERROR)
    end

    context "in a container environment" do
      around { |example| in_container_env(example) }

      it "will honor the log level in the container logger" do
        log = described_class.create_logger(log_file_name)
        container_log = log.wrapped_logger

        described_class.apply_config_value({:level_foo => :error}, log, :level_foo)

        expect(log.level).to           eq(Logger::ERROR)
        expect(container_log.level).to eq(Logger::ERROR)
      end
    end
  end

  describe ".contents" do
    let(:logfile) { Pathname.new(__dir__).join("data/miq_ascii.log") }

    let(:ascii_log_content) { logfile.read.chomp }
    let(:ascii_log_tail)    { ascii_log_content.split("\n").last(2).join("\n") }

    it "with missing log" do
      logfile = Pathname.new(__dir__).join("data/miq_missing.log")

      expect(described_class.contents(logfile)).to be_empty
    end

    it "with empty log" do
      logfile = Pathname.new(__dir__).join("data/miq_empty.log")

      expect(described_class.contents(logfile)).to be_empty
    end

    it "without tail" do
      expect(described_class.contents(logfile)).to eq(ascii_log_content)
    end

    it "with tail" do
      expect(described_class.contents(logfile, 2)).to eq(ascii_log_tail)
    end

    it "with tail set to nil to return the whole file" do
      expect(described_class.contents(logfile, nil)).to eq(ascii_log_content)
    end

    it "with Logger(file)" do
      log = Logger.new(logfile)

      expect(described_class.contents(log)).to eq(ascii_log_content)
    end

    it "with Logger(IO)" do
      log = Logger.new($stdout)

      expect(described_class.contents(log)).to be_empty
    end

    it "with ManageIQ::Loggers::Base object" do
      log = ManageIQ::Loggers::Base.new(logfile)

      expect(described_class.contents(log)).to eq(ascii_log_content)
    end

    context "with evm log snippet with invalid utf8 byte sequence data" do
      let(:logfile) { Pathname.new(__dir__).join("data/redundant_utf8_byte_sequence.log") }

      context "accessing the invalid data directly" do
        subject { logfile.read }

        it "should have content with the invalid utf8 lines" do
          expect(subject).not_to be_nil
          expect(subject).to     be_kind_of(String)
        end

        it "should unpack raw data as UTF-8 characters and raise ArgumentError" do
          expect { subject.unpack("U*") }.to raise_error(ArgumentError)
        end
      end

      context "with line limit" do
        subject { described_class.contents(logfile, 1000) }

        it "should have content but without the invalid utf8 lines" do
          expect(subject).not_to be_nil
          expect(subject).to     be_kind_of(String)
        end

        it "should unpack logger contents as UTF-8 characters and raise nothing" do
          expect { subject.unpack("U*") }.not_to raise_error
        end
      end

      context "without line limit" do
        subject { described_class.contents(logfile, nil) }

        it "should have content but without the invalid utf8 lines" do
          expect(subject).not_to be_nil
          expect(subject).to     be_kind_of(String)
        end

        it "should unpack logger contents as UTF-8 characters and raise nothing" do
          expect { subject.unpack("U*") }.not_to raise_error
        end
      end

      context "encoding" do
        it "with ascii file" do
          logfile = Pathname.new(__dir__).join("data/miq_ascii.log")

          expect(described_class.contents(logfile).encoding.name).to eq("UTF-8")
          expect(described_class.contents(logfile, nil).encoding.name).to eq("UTF-8")
        end

        it "with utf-8 file" do
          logfile = Pathname.new(__dir__).join("data/miq_utf8.log")

          expect(described_class.contents(logfile).encoding.name).to eq("UTF-8")
          expect(described_class.contents(logfile, nil).encoding.name).to eq("UTF-8")
        end
      end
    end
  end
end
