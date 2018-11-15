describe InterRegionApiMethodRelay do
  let(:collection_name) { :test_class_collection }
  let(:api_config)      { double("Api::CollectionConfig") }

  context "with a valid class definition" do
    let!(:test_class) do
      allow(Api::CollectionConfig).to receive(:new).and_return(api_config)
      allow(api_config).to receive(:name_for_klass).and_return(collection_name)

      Class.new do
        extend InterRegionApiMethodRelay

        def self.name
          "RegionalMethodRelayTestClass"
        end

        def test_instance_method
          "my test instance method"
        end
        api_relay_method :test_instance_method

        def test_instance_method_action
        end
        api_relay_method :test_instance_method_action, :test_instance_method

        def test_instance_method_arg(arg)
          block_given? ? yield(arg) : arg
        end
        api_relay_method :test_instance_method_arg do |arg|
          arg
        end

        def self.test_class_method(arg)
          block_given? ? yield(arg.to_s) : arg.to_s
        end
        api_relay_class_method :test_class_method do |arg|
          [arg[0], arg[1]]
        end

        def self.test_class_method_action(_arg)
        end
        api_relay_class_method :test_class_method_action, :test_class_method do |arg|
          [arg[0], arg[1]]
        end
      end
    end

    describe ".extended" do
      it "properly creates the relay classes" do
        expect(test_class.ancestors.first).to eq(test_class::InstanceMethodRelay)
        expect(test_class.singleton_class.ancestors.first).to eq(test_class::ClassMethodRelay)
      end
    end

    describe "method defined by #api_relay_method" do
      let(:test_instance) { test_class.new }

      context "when the instance is in my region" do
        before do
          expect(test_instance).to receive(:in_current_region?).and_return(true)
        end

        it "calls the original" do
          expect(test_instance.test_instance_method).to eq("my test instance method")
        end

        it "calls the original with arguments" do
          expect(test_instance.test_instance_method_arg(5)).to eq(5)
        end

        it "calls the original with a block" do
          expect { |b| test_instance.test_instance_method_arg(5, &b) }.to yield_with_args(5)
        end
      end

      context "when the instance is not in my region" do
        let(:id)     { 123 }
        let(:region) { 0 }
        before do
          expect(test_instance).to receive(:in_current_region?).and_return(false)
          expect(test_instance).to receive(:region_number).and_return(region)
          expect(test_instance).to receive(:id).and_return(id)
        end

        def expect_api_call(expected_action, expected_args = nil)
          expect(described_class).to receive(:exec_api_call) do |region_num, collection, action, args, instance_id|
            expect(region_num).to eq(region)
            expect(collection).to eq(collection_name)
            expect(action).to eq(expected_action)
            expect(args).to eq(expected_args) if expected_args
            expect(instance_id).to eq(id)
          end
        end

        it "executes the method name as an action by default" do
          expect_api_call(:test_instance_method)
          test_instance.test_instance_method
        end

        it "executes the action name if given" do
          expect_api_call(:test_instance_method)
          test_instance.test_instance_method_action
        end

        it "passes the result of the block as post args" do
          post_args = {:my => "post args"}
          expect_api_call(:test_instance_method_arg, post_args)
          test_instance.test_instance_method_arg(post_args)
        end
      end
    end

    describe "method defined by #api_relay_class_method" do
      let(:id)          { 5 }
      let(:post_args)   { {:do => "these things"} }
      let(:method_arg)  { [id, post_args] }

      context "when the subject is in my region" do
        before do
          expect(test_class).to receive(:id_in_current_region?).with(id).and_return(true)
        end

        it "calls the original" do
          expect(test_class.test_class_method(method_arg)).to eq(method_arg.to_s)
        end

        it "calls the original with a block" do
          expect { |b| test_class.test_class_method(method_arg, &b) }.to yield_with_args(method_arg.to_s)
        end
      end

      context "when the subject is nil" do
        let(:expected) { "[nil, {:do=>\"these things\"}]" }
        it "calls the original" do
          expect(test_class.test_class_method([nil, post_args])).to eq(expected)
        end

        it "calls the original with a block" do
          expect { |b| test_class.test_class_method([nil, post_args], &b) }.to yield_with_args(expected)
        end
      end

      context "when the subject is not in my region" do
        let(:region) { 0 }

        before do
          expect(test_class).to receive(:id_in_current_region?).with(id).and_return(false)
          expect(test_class).to receive(:id_to_region).with(id).and_return(region)
        end

        it "executes the method name action by default with the second yielded parameter" do
          expect(described_class).to receive(:exec_api_call)
            .with(region, collection_name, :test_class_method, post_args)
          test_class.test_class_method(method_arg)
        end

        it "executes the action name if given" do
          expect(described_class).to receive(:exec_api_call)
            .with(region, collection_name, :test_class_method, post_args)
          test_class.test_class_method_action(method_arg)
        end
      end
    end

    describe ".api_client_connection_for_region" do
      let!(:server)           { EvmSpecHelper.local_miq_server(:has_active_webservices => true) }
      let!(:region)           { FactoryGirl.create(:miq_region, :region => region_number) }
      let(:region_number)     { ApplicationRecord.my_region_number }
      let(:request_user)      { "test_user" }
      let(:api_connection)    { double("ManageIQ::API::Client connection") }
      let(:region_auth_token) { double("MiqRegion API auth token") }

      before do
        allow(MiqRegion).to receive(:find_by).with(:region => region_number).and_return(region)
      end

      it "opens an api connection to that address when the server has an ip address" do
        require "manageiq-api-client"

        server.ipaddress = "192.0.2.1"
        server.save!

        expect(User).to receive(:current_userid).and_return(request_user)
        expect(region).to receive(:api_system_auth_token).with(request_user).and_return(region_auth_token)

        client_connection_hash = {
          :url      => "https://#{server.ipaddress}",
          :miqtoken => region_auth_token,
          :ssl      => {:verify => false}
        }
        expect(ManageIQ::API::Client).to receive(:new).with(client_connection_hash).and_return(api_connection)
        described_class.api_client_connection_for_region(region_number)
      end

      it "raises if the server doesn't have an ip address" do
        expect {
          described_class.api_client_connection_for_region(region_number)
        }.to raise_error("Failed to establish API connection to region #{region_number}")
      end
    end

    describe ".exec_api_call" do
      let(:region)             { 0 }
      let(:action)             { :the_action }
      let(:api_connection)     { double("ManageIQ::API::Client Connection") }
      let(:api_collection)     { double("ManageIQ::API::Client Collection", :name => collection_name) }
      let(:api_success_result) { ManageIQ::API::Client::ActionResult.new("success" => true, "message" => "success!") }
      let(:api_failure_result) { ManageIQ::API::Client::ActionResult.new("success" => false, "message" => "failure!") }
      let(:api_resource)       { ManageIQ::API::Client::Resource.subclass("test_resource").new(api_collection, {}) }

      before do
        expect(described_class).to receive(:api_client_connection_for_region).with(region).and_return(api_connection)
        expect(api_connection).to receive(collection_name).and_return(api_collection)
      end

      it "finds the instance when the api returns a resource" do
        instance = double("ActiveRecord instance")
        expect(api_collection).to receive(action).and_return(api_resource)
        expect(described_class).to receive(:instance_for_resource).with(api_resource).and_return(instance)

        expect(described_class.exec_api_call(region, collection_name, action)).to eq(instance)
      end

      it "raises when the api result is a failure" do
        expect(api_collection).to receive(action).and_return(api_failure_result)
        expect {
          described_class.exec_api_call(region, collection_name, action)
        }.to raise_error(described_class::InterRegionApiMethodRelayError)
      end

      it "accepts Hash object as api result" do
        expect(api_collection).to receive(action).and_return({})
        expect { described_class.exec_api_call(region, collection_name, action) }.not_to raise_error
      end

      it "calls the given action with the given args" do
        args = {:my => "args", :here => 123}
        expect(api_collection).to receive(action).with(args).and_return(api_success_result)
        expect(described_class.exec_api_call(region, collection_name, action, args)).to eq(api_success_result.attributes)
      end

      it "defaults the args to an empty hash" do
        expect(api_collection).to receive(action).with({}).and_return(api_success_result)
        expect(described_class.exec_api_call(region, collection_name, action)).to eq(api_success_result.attributes)
      end

      it "defaults the args to an empty hash when nil is explicitly passed as args" do
        expect(api_collection).to receive(action).with({}).and_return(api_success_result)
        expect(described_class.exec_api_call(region, collection_name, action, nil)).to eq(api_success_result.attributes)
      end

      it "calls a method on an instance if id is passed" do
        instance = double("instance")
        expect(api_collection).to receive(:find).with(4).and_return(instance)
        expect(instance).to receive(action).and_return(api_success_result)
        expect(described_class.exec_api_call(region, collection_name, action, nil, 4)).to eq(api_success_result.attributes)
      end
    end
  end

  describe ".instance_for_resource" do
    let(:collection) { double("ManageIQ::API::Client::Collection", :name => collection_name) }
    let(:resource)   { double("ManageIQ::API::Client::Resource", :collection => collection, :id => 10) }
    let(:klass)      { double("MyTestClass") }
    let(:instance)   { double("MyTestClass instance") }

    before do
      allow(Api::CollectionConfig).to receive(:new).and_return(api_config)
      stub_const("InterRegionApiMethodRelay::INITIAL_INSTANCE_WAIT", 0.01)
      stub_const("InterRegionApiMethodRelay::MAX_INSTANCE_WAIT", 0.03)
    end

    it "finds the instance with the returned id" do
      expect(api_config).to receive(:klass).with(collection_name).and_return(klass)
      expect(klass).to receive(:find_by).with(:id => 10).and_return(instance)

      expect(described_class.instance_for_resource(resource)).to eq(instance)
    end

    it "retries if it can't find the instance" do
      expect(api_config).to receive(:klass).with(collection_name).and_return(klass)
      expect(klass).to receive(:find_by).twice.with(:id => 10).and_return(nil, instance)

      expect(described_class.instance_for_resource(resource)).to eq(instance)
    end

    it "raises if it can't find the instance within the timeout" do
      expect(api_config).to receive(:klass).with(collection_name).and_return(klass)
      expect(klass).to receive(:find_by).twice.with(:id => 10).and_return(nil, nil)

      expect {
        described_class.instance_for_resource(resource)
      }.to raise_error(InterRegionApiMethodRelay::InterRegionApiMethodRelayError)
    end
  end

  context "with an invalid class definition" do
    describe "#api_relay_method" do
      it "raises a NotImplementedError if the class does not have an api collection" do
        expect {
          Class.new do
            extend InterRegionApiMethodRelay

            def self.name
              "RegionalMethodRelayTestClass"
            end

            def test_instance_method
              "my test instance method"
            end
            api_relay_method :test_instance_method
          end
        }.to raise_error(NotImplementedError)
      end
    end

    describe "#api_relay_class_method" do
      it "raises a NotImplementedError if the class does not have an api collection" do
        expect {
          Class.new do
            extend InterRegionApiMethodRelay

            def self.name
              "RegionalMethodRelayTestClass"
            end

            def self.test_instance_method
              "my test instance method"
            end
            api_relay_class_method :test_instance_method do
            end
          end
        }.to raise_error(NotImplementedError)
      end

      it "raises a ArgumentError if no block is defined" do
        allow(Api::CollectionConfig).to receive(:new).and_return(api_config)
        allow(api_config).to receive(:name_for_klass).and_return(collection_name)
        expect {
          Class.new do
            extend InterRegionApiMethodRelay

            def self.name
              "RegionalMethodRelayTestClass"
            end

            def self.test_instance_method
              "my test instance method"
            end
            api_relay_class_method :test_instance_method
          end
        }.to raise_error(ArgumentError)
      end
    end
  end
end
