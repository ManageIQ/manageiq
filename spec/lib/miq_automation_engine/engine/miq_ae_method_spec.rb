describe MiqAeEngine::MiqAeMethod do
  describe ".invoke_inline_ruby (private)" do
    let(:workspace) do
      Class.new do
        attr_accessor :invoker
        # rubocop:disable Style/SingleLineMethods, Style/EmptyLineBetweenDefs
        def persist_state_hash; end
        def disable_rbac; end
        def current_method; "/my/automate/method"; end
        # rubocop:enable Style/SingleLineMethods, Style/EmptyLineBetweenDefs
      end.new
    end

    let(:aem)    { double("AEM", :data => script, :fqname => "/my/automate/method") }
    let(:obj)    { double("OBJ", :workspace => workspace) }
    let(:inputs) { [] }

    subject { described_class.send(:invoke_inline_ruby, aem, obj, inputs) }

    context "with a script that ends normally" do
      let(:script) do
        <<-RUBY
          puts 'Hi from puts'
        RUBY
      end

      it "logs and returns the correct exit status" do
        allow($miq_ae_logger).to receive(:info).and_call_original
        expect($miq_ae_logger).to receive(:info).with("Method exited with rc=MIQ_OK").at_least(:once)
        expect($miq_ae_logger).to_not receive(:error)

        expect(subject).to eq(0)
      end
    end

    context "with a script that raises" do
      let(:script) do
        <<-RUBY
          puts 'Hi from puts'
          raise
        RUBY
      end

      it "logs the error with file and line numbers changed in the stacktrace, and raises an exception" do
        allow($miq_ae_logger).to receive(:error).and_call_original
        expect($miq_ae_logger).to receive(:error).with("Method STDERR: /my/automate/method:2:in `<main>': unhandled exception").at_least(:once)

        expect { subject }.to raise_error(MiqAeException::UnknownMethodRc)
      end
    end

    context "with a script that raises in a nested method" do
      let(:script) do
        <<-RUBY
          def my_method
            raise
          end

          puts 'Hi from puts'
          my_method
        RUBY
      end

      it "logs the error with file and line numbers changed in the stacktrace, and raises an exception" do
        allow($miq_ae_logger).to receive(:error).and_call_original
        expect($miq_ae_logger).to receive(:error).with("Method STDERR: /my/automate/method:2:in `my_method': unhandled exception").at_least(:once)
        expect($miq_ae_logger).to receive(:error).with("Method STDERR: \tfrom /my/automate/method:6:in `<main>'").at_least(:once)

        expect { subject }.to raise_error(MiqAeException::UnknownMethodRc)
      end
    end

    context "with a script that exits" do
      let(:script) do
        <<-RUBY
          puts 'Hi from puts'
          exit
        RUBY
      end

      it "logs and returns the correct exit status" do
        allow($miq_ae_logger).to receive(:info).and_call_original
        expect($miq_ae_logger).to receive(:info).with("Method exited with rc=MIQ_OK").at_least(:once)
        expect($miq_ae_logger).to_not receive(:error)

        expect(subject).to eq(0)
      end
    end

    context "with a script that exits with an unknown return code" do
      let(:script) do
        <<-RUBY
          puts 'Hi from puts'
          exit 1234
        RUBY
      end

      it "does not log but raises an exception" do
        expect($miq_ae_logger).to_not receive(:error)

        expect { subject }.to raise_error(MiqAeException::UnknownMethodRc)
      end
    end

    context "with a script that exits MIQ_OK" do
      let(:script) do
        <<-RUBY
          puts 'Hi from puts'
          exit MIQ_OK
        RUBY
      end

      it "logs and returns the correct exit status" do
        allow($miq_ae_logger).to receive(:info).and_call_original
        expect($miq_ae_logger).to receive(:info).with("Method exited with rc=MIQ_OK").at_least(:once)
        expect($miq_ae_logger).to_not receive(:error)

        expect(subject).to eq(0)
      end
    end

    context "with a script that exits MIQ_WARN" do
      let(:script) do
        <<-RUBY
          puts 'Hi from puts'
          exit MIQ_WARN
        RUBY
      end

      it "logs and returns the correct exit status" do
        allow($miq_ae_logger).to receive(:warn).and_call_original
        expect($miq_ae_logger).to receive(:warn).with("Method exited with rc=MIQ_WARN").at_least(:once)
        expect($miq_ae_logger).to_not receive(:error)

        expect(subject).to eq(4)
      end
    end

    context "with a script that exits MIQ_STOP" do
      let(:script) do
        <<-RUBY
          puts 'Hi from puts'
          exit MIQ_STOP
        RUBY
      end

      it "does not log but raises an exception" do
        expect($miq_ae_logger).to_not receive(:error)

        expect { subject }.to raise_error(MiqAeException::StopInstantiation)
      end
    end

    context "with a script that exits MIQ_ABORT" do
      let(:script) do
        <<-RUBY
          puts 'Hi from puts'
          exit MIQ_ABORT
        RUBY
      end

      it "does not log but raises an exception" do
        expect($miq_ae_logger).to_not receive(:error)

        expect { subject }.to raise_error(MiqAeException::AbortInstantiation)
      end
    end

    context "with a script that does I/O" do
      let(:script) do
        <<-RUBY
          puts 'Hi from puts'
          STDOUT.puts 'Hi from STDOUT.puts'
          $stdout.puts 'Hi from $stdout.puts'
          STDERR.puts 'Hi from STDERR.puts'
          $stderr.puts 'Hi from $stderr.puts'
          $evm.logger.sleep
        RUBY
      end

      it "writes to the logger synchronously" do
        logger_stub = Class.new do
          attr_reader :expected_messages

          def initialize
            @expected_messages = [
              "Method STDOUT: Hi from puts",
              "Method STDOUT: Hi from STDOUT.puts",
              "Method STDOUT: Hi from $stdout.puts",
              "Method STDERR: Hi from STDERR.puts",
              "Method STDERR: Hi from $stderr.puts",
            ]
          end

          def sleep
            # Raise if all messages have not already been written before a method like sleep runs.
            raise unless expected_messages == []
          end

          def verify_next_message(message)
            expected = expected_messages.shift
            return if message == expected
            puts "Expected: #{expected.inspect}, Got: #{message.inspect}"
            raise
          end
          alias_method :error, :verify_next_message
          alias_method :info,  :verify_next_message
        end.new

        svc = MiqAeMethodService::MiqAeService.new(workspace, [], logger_stub)
        expect(MiqAeMethodService::MiqAeService).to receive(:new).with(workspace, []).and_return(svc)

        expect($miq_ae_logger).to receive(:info).with("<AEMethod [/my/automate/method]> Starting ").ordered
        expect(logger_stub).to    receive(:sleep).and_call_original.ordered
        expect($miq_ae_logger).to receive(:info).with("<AEMethod [/my/automate/method]> Ending").ordered
        expect($miq_ae_logger).to receive(:info).with("Method exited with rc=MIQ_OK").ordered

        expect(subject).to eq(0)
        expect(logger_stub.expected_messages).to eq([])
      end
    end
  end
end
