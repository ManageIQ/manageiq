describe ProcessTasksMixin do
  let(:test_class) do
    Class.new(ApplicationRecord) do
      include ProcessTasksMixin
      def self.name
        "ProcessTasksMixinTestClass"
      end

      def test_method
        "a test"
      end
    end
  end

  describe ".process_tasks" do
    context "class responds to refresh_ems" do
      before do
        test_class.define_singleton_method(:refresh_ems, ->(_ids) { "refresh that ems" })
      end

      it "calls .refresh_ems and raises an audit event" do
        ids = [1, 2, 3]
        expect(test_class).to receive(:refresh_ems).with(ids)
        expect(AuditEvent).to receive(:success)
        test_class.process_tasks(:task => "refresh_ems", :ids => ids)
      end
    end

    it "queues a message for the specified task" do
      EvmSpecHelper.create_guid_miq_server_zone
      test_class.process_tasks(:task => "test_method", :ids => [5], :userid => "admin")

      message = MiqQueue.first

      expect(message.class_name).to eq(test_class.name)
      message.args.each do |h|
        expect(h[:task]).to eq("test_method")
        expect(h[:ids]).to eq([5])
        expect(h[:userid]).to eq("admin")
      end
    end

    it "defaults the userid to system in the queue message" do
      EvmSpecHelper.create_guid_miq_server_zone
      test_class.process_tasks(:task => "test_method", :ids => [5])

      message = MiqQueue.first

      expect(message.class_name).to eq(test_class.name)
      message.args.each do |h|
        expect(h[:task]).to eq("test_method")
        expect(h[:ids]).to eq([5])
        expect(h[:userid]).to eq("system")
      end
    end

    it "raises if no ids are given" do
      expect { test_class.process_tasks(:task => "test_method", :ids => []) }.to raise_error(RuntimeError)
      expect { test_class.process_tasks(:task => "test_method") }.to raise_error(RuntimeError)
    end

    it "raises if the task is an unknown method" do
      expect { test_class.process_tasks(:task => "bad_method", :ids => [1]) }.to raise_error(RuntimeError)
    end
  end
end
