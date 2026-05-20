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

      let(:native_logger) { subject.try(:broadcasts).try(:last) }

      before do
        # Hide the native logger output to STDOUT
        allow(native_logger.logdev).to receive(:write)
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
        expect(subject.broadcasts.first.logdev).to be_nil
        expect(native_logger.logdev).to be_a Logger::LogDevice
      end

      describe "#datetime_format" do
        it "return nil" do
          expect(subject.datetime_format.first).to be nil
          expect(subject.datetime_format.last).to be nil
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
            expect(subject.broadcasts.first).to receive(:add).with(1, nil, "test message").and_call_original
            expect(subject.broadcasts.last).to receive(:add).with(1, nil, "test message").and_call_original
            subject.info("test message")
          end

          it "only forwards the message if the severity is correct" do
            expect(subject.broadcasts.first.logdev).to be_nil
            expect(native_logger.logdev).not_to receive(:write).with("test message")

            subject.debug("test message")
          end

          it "logs the correct progname" do
            expected_progname = log_file_name.chomp(".log")

            if native_logger.kind_of?(ManageIQ::Loggers::Container)
              expect(native_logger.logdev).to receive(:write).with(a_string_including("\"service\":\"#{expected_progname}\""))
            else
              expect(native_logger.logdev).to receive(:write).with(a_string_including(expected_progname))
            end

            subject.info("test message")
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
          expect(native_logger).to receive(:<<).with("test message").and_call_original

          subject << "test message"
        end
      end

      context "with an IO" do
        let(:log_file) { StringIO.new }

        it "logs correctly" do
          expect(subject.broadcasts.first).to receive(:add).with(1, nil, "test message").and_call_original
          expect(subject.broadcasts.last).to receive(:add).with(1, nil, "test message").and_call_original

          subject.info("test message")
        end
      end

      context "with a Pathname" do
        let(:log_file) { Rails.root.join("tmp/logger_pathname.log") }

        after { log_file.delete if log_file.exist? }

        it "logs correctly" do
          expect(subject.broadcasts.first).to receive(:add).with(1, nil, "test message").and_call_original
          expect(subject.broadcasts.last).to receive(:add).with(1, nil, "test message").and_call_original

          subject.info("test message")
        end

        it "logs the correct progname" do
          expected_progname = "logger_pathname"

          if native_logger.kind_of?(ManageIQ::Loggers::Container)
            expect(native_logger.logdev).to receive(:write).with(a_string_including("\"service\":\"#{expected_progname}\""))
          else
            expect(native_logger.logdev).to receive(:write).with(a_string_including(expected_progname))
          end

          subject.info("test message")
        end
      end

      context "with a full path String" do
        let(:log_file) { Rails.root.join("tmp/logger_string.log").to_s }

        after { File.delete(log_file) if File.exist?(log_file) }

        it "logs correctly" do
          expect(subject.broadcasts.first).to receive(:add).with(1, nil, "test message").and_call_original
          expect(subject.broadcasts.last).to receive(:add).with(1, nil, "test message").and_call_original
          subject.info("test message")
        end

        it "logs the correct progname" do
          expected_progname = "logger_string"

          if native_logger.kind_of?(ManageIQ::Loggers::Container)
            expect(native_logger.logdev).to receive(:write).with(a_string_including("\"service\":\"#{expected_progname}\""))
          else
            expect(native_logger.logdev).to receive(:write).with(a_string_including(expected_progname))
          end

          subject.info("test message")
        end
      end
    end

    context "in a non-container environment" do
      it "has a file logger as the broadcast logger" do
        expect(native_logger).to be_a(ManageIQ::Loggers::File)
      end

      include_examples "has basic logging functionality"
    end

    context "in a container environment" do
      around { |example| in_container_env(example) }

      it "has a container logger" do
        expect(native_logger).to_not be_nil
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
        native_logger = log.broadcasts.last

        described_class.apply_config_value({:level_foo => :error}, log, :level_foo)
        expect(log.level).to           eq(Logger::ERROR)
        expect(native_logger.level).to eq(Logger::ERROR)

        described_class.apply_config_value({:level_foo => :debug}, log, :level_foo)
        expect(log.level).to           eq(Logger::DEBUG)
        expect(native_logger.level).to eq(Logger::DEBUG)
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
      log = ManageIQ::Loggers::File.new(logfile)
      expect(described_class.contents(log)).to eq(ascii_log_content)
    end

    it "with tail" do
      log = ManageIQ::Loggers::File.new(logfile)
      expect(described_class.contents(log, 2)).to eq(ascii_log_tail)
    end

    it "with tail set to nil to return the whole file" do
      log = ManageIQ::Loggers::File.new(logfile)
      # Pass a very large number instead of nil to get all lines
      expect(described_class.contents(log, 999_999)).to eq(ascii_log_content)
    end

    it "with ManageIQ::Loggers::File object" do
      log = ManageIQ::Loggers::File.new(logfile)

      expect(described_class.contents(log)).to eq(ascii_log_content)
    end

    it "with ActiveSupport::BroadcastLogger wrapping ManageIQ logger" do
      log = described_class.send(:create_wrapper_logger, "test", ManageIQ::Loggers::Base, ManageIQ::Loggers::Base.new($stdout))

      expect(described_class.contents(log)).to eq("")
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
