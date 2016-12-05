describe MiqAeEngine::MiqAeMethod do
  context ".invoke_inline_ruby(private)" do
    it "writes to the logger immediately" do
      script = <<-EOS
        puts 'Hi from puts'
        STDOUT.puts 'Hi from STDOUT.puts'
        $stdout.puts 'Hi from $stdout.puts'
        STDERR.puts 'Hi from STDERR.puts'
        $stderr.puts 'Hi from $stderr.puts'
        $evm.logger.sleep
      EOS

      workspace = Class.new do
        attr_accessor :invoker

        def persist_state_hash
        end

        def disable_rbac
        end
      end.new

      logger_klass = Class.new do
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
          expected = @expected_messages.shift
          return if message == expected
          puts "Expected: #{expected.inspect}, Got: #{message.inspect}"
          raise
        end
        alias_method :error, :verify_next_message
        alias_method :info,  :verify_next_message
      end

      aem         = double("AEM", :data => script, :fqname => "fqname")
      inputs      = []
      logger_stub = logger_klass.new
      obj         = double("OBJ", :workspace => workspace)
      svc         = MiqAeMethodService::MiqAeService.new(workspace, inputs, aem.data, logger_stub)

      expect(MiqAeMethodService::MiqAeService).to receive(:new).with(workspace, inputs, aem.data).and_return(svc)

      expect($miq_ae_logger).to receive(:info).with("<AEMethod [fqname]> Starting ").ordered
      expect(logger_stub).to    receive(:sleep).and_call_original.ordered
      expect($miq_ae_logger).to receive(:info).with("<AEMethod [fqname]> Ending").ordered
      expect($miq_ae_logger).to receive(:info).with("Method exited with rc=MIQ_OK").ordered

      expect(described_class.send(:invoke_inline_ruby, aem, obj, inputs)).to eq(0)

      expect(logger_stub.expected_messages).to eq([])
    end
  end
end
