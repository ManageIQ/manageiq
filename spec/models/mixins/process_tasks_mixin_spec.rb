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
    let!(:server)          { EvmSpecHelper.local_miq_server(:has_active_webservices => true) }
    let(:region_seq_start) { ApplicationRecord.rails_sequence_start }
    let(:request_user)     { "test_user" }
    let(:test_options) do
      {
        :ids          => [region_seq_start, region_seq_start + 1, region_seq_start + 2],
        :other_option => "some option",
        :userid       => request_user
      }
    end

    before do
      FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
    end

    context "when the server has an ip address" do
      let(:api_connection)    { double("ManageIQ::API::Client connection") }

      before do
        server.ipaddress = "192.0.2.1"
        server.save!
      end

      it "calls invoke_api_tasks with the api connection and options" do
        expect(InterRegionApiMethodRelay).to receive(:api_client_connection_for_region)
          .with(ApplicationRecord.my_region_number, request_user)
          .and_return(api_connection)

        expect(test_class).to receive(:invoke_api_tasks).with(api_connection, test_options)
        test_class.invoke_tasks_remote(test_options)
      end

      it "requeues invoke_tasks_remote when invoke_api_tasks fails" do
        expect(InterRegionApiMethodRelay).to receive(:api_client_connection_for_region)
        expect(test_class).to receive(:invoke_api_tasks).and_raise(RuntimeError)
        test_class.invoke_tasks_remote(test_options)

        message = MiqQueue.first

        expect(message.class_name).to eq(test_class.name)
        expect(message.method_name).to eq("invoke_tasks_remote")
        expect(message.args).to eq([test_options])
      end

      it "does not requeue for a NotImplementedError" do
        expect(InterRegionApiMethodRelay).to receive(:api_client_connection_for_region)
        expect(test_class).to receive(:invoke_api_tasks).and_raise(NotImplementedError)
        expect(MiqQueue).not_to receive(:put)
        test_class.invoke_tasks_remote(test_options)
      end
    end

    it "requeues if the server does not have an address" do
      test_class.invoke_tasks_remote(test_options)

      expect(MiqQueue.first).to have_attributes(
        :class_name  => test_class.name,
        :method_name => "invoke_tasks_remote",
        :args        => [test_options]
      )
    end
  end

  describe ".invoke_api_tasks" do
    it "raises NotImplementedError when called on a class with no API collection" do
      expect { test_class.invoke_api_tasks(double("api_client"), {}) }.to raise_error(NotImplementedError)
    end

    context "with a valid class name" do
      let(:collection_name) { :test_class_collection }
      let(:api_connection)  { double("ManageIQ::API::Client connection") }
      let(:api_collection)  { double("ManageIQ::API::Client collection") }

      before do
        api_config = double("Api::CollectionConfig")
        expect(Api::CollectionConfig).to receive(:new).and_return(api_config)
        expect(api_config).to receive(:name_for_klass).and_return(collection_name)
        expect(api_connection).to receive(collection_name).and_return(api_collection)
      end

      context "when not passed resource ids" do
        it "calls the action on the collection" do
          options = {
            :task => "the_task",
            :args => {:many => ["arguments"], :go => "here"}
          }
          expect(api_collection).to receive(:the_task).with(options[:args])

          test_class.invoke_api_tasks(api_connection, options)
        end

        it "uses an empty hash for the args if they are not in the options" do
          options = {
            :task => "the_task"
          }
          expect(api_collection).to receive(:the_task).with({})

          test_class.invoke_api_tasks(api_connection, options)
        end
      end

      it "with missing remote resource does not raise" do
        resource0 = double("resource0", :id => 0)
        expect(api_collection).to receive(:find).with(0).and_raise(ManageIQ::API::Client::ResourceNotFound, "Couldn't find resource with 'id' [0]")
        options = {
          :ids  => [0],
          :task => "the_task",
          :args => {:some => "args"}
        }
        expect(resource0).not_to receive(:the_task)

        expect { test_class.invoke_api_tasks(api_connection, options) }.not_to raise_error
      end

      context "when passed resource ids" do
        let(:resource0)     { double("resource0", :id => 0) }
        let(:resource1)     { double("resource1", :id => 1) }

        before do
          expect(api_collection).to receive(:find).with(0).and_return(resource0)
          expect(api_collection).to receive(:find).with(1).and_return(resource1)
        end

        it "executes the task on each resource" do
          options = {
            :ids  => [0, 1],
            :task => "the_task",
            :args => {:some => "args"}
          }
          expect(resource0).to receive(:the_task).with(options[:args])
          expect(resource1).to receive(:the_task).with(options[:args])

          test_class.invoke_api_tasks(api_connection, options)
        end

        it "uses an empty hash for the args if they are not in the options" do
          options = {
            :ids  => [0, 1],
            :task => "the_task"
          }
          expect(resource0).to receive(:the_task).with({})
          expect(resource1).to receive(:the_task).with({})

          test_class.invoke_api_tasks(api_connection, options)
        end
      end
    end
  end
end
