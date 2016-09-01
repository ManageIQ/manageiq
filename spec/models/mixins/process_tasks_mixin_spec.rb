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

  describe ".invoke_tasks_remote" do
    let(:server)           { EvmSpecHelper.local_miq_server(:has_active_webservices => true) }
    let(:region_seq_start) { ApplicationRecord.rails_sequence_start }
    let(:test_options) do
      {
        :ids          => [region_seq_start, region_seq_start + 1, region_seq_start + 2],
        :other_option => "some option"
      }
    end

    before do
      FactoryGirl.create(:miq_region, :region => server.region_number)
    end

    context "when the server has an ip address" do
      before do
        server.ipaddress = "192.0.2.1"
        server.save!
      end

      it "calls invoke_api_tasks with the server ip and ids" do
        expect(test_class).to receive(:invoke_api_tasks).with(server.ipaddress, test_options)
        test_class.invoke_tasks_remote(test_options)
      end

      it "requeues invoke_tasks_remote when invoke_api_tasks fails" do
        expect(test_class).to receive(:invoke_api_tasks).and_raise(RuntimeError)
        test_class.invoke_tasks_remote(test_options)

        message = MiqQueue.first

        expect(message.class_name).to eq(test_class.name)
        expect(message.method_name).to eq("invoke_tasks_remote")
        expect(message.args).to eq([test_options])
      end
    end

    it "does not call invoke_api_tasks if the server does not have an address" do
      expect(test_class).not_to receive(:invoke_api_tasks)
      test_class.invoke_tasks_remote(test_options)
    end
  end
end
