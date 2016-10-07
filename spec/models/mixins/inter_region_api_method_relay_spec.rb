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
        let(:api_connection) { double("ManageIQ::Api::Client connection") }
        let(:api_collection) { double("ManageIQ::Api::Client collection") }
        let(:api_resource)   { double("ManageIQ::Api::Client resource") }

        before do
          expect(test_instance).to receive(:in_current_region?).and_return(false)
          expect(test_instance).to receive(:region_number).and_return(0)
          expect(test_instance).to receive(:id).and_return(123)

          expect(described_class).to receive(:api_client_connection_for_region).with(0).and_return(api_connection)
          expect(api_connection).to receive(collection_name).and_return(api_collection)
          expect(api_collection).to receive(:find).with(123).and_return(api_resource)
        end

        it "executes the method name as an action by default" do
          expect(api_resource).to receive(:test_instance_method).with({})
          test_instance.test_instance_method
        end

        it "executes the action name if given" do
          expect(api_resource).to receive(:test_instance_method).with({})
          test_instance.test_instance_method_action
        end

        it "passes the result of the block as post args" do
          post_args = {:my => "post args"}
          expect(api_resource).to receive(:test_instance_method_arg).with(post_args)
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

      context "when the subject is not in my region" do
        let(:api_connection) { double("ManageIQ::Api::Client connection") }
        let(:api_collection) { double("ManageIQ::Api::Client collection") }

        before do
          expect(test_class).to receive(:id_in_current_region?).with(id).and_return(false)
          expect(test_class).to receive(:id_to_region).with(id).and_return(0)
          expect(described_class).to receive(:api_client_connection_for_region).with(0).and_return(api_connection)
          expect(api_connection).to receive(collection_name).and_return(api_collection)
        end

        it "executes the method name action by default with the second yielded parameter" do
          expect(api_collection).to receive(:test_class_method).with(post_args)
          test_class.test_class_method(method_arg)
        end

        it "executes the action name if given" do
          expect(api_collection).to receive(:test_class_method).with(post_args)
          test_class.test_class_method_action(method_arg)
        end
      end
    end

    describe ".api_client_connection_for_region" do
      let!(:server)           { EvmSpecHelper.local_miq_server(:has_active_webservices => true) }
      let(:region_seq_start)  { ApplicationRecord.rails_sequence_start }
      let(:request_user)      { "test_user" }
      let(:api_connection)    { double("ManageIQ::API::Client connection") }
      let(:region_auth_token) { double("MiqRegion API auth token") }

      before do
        FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
      end

      it "opens an api connection to that address when the server has an ip address" do
        require "manageiq-api-client"

        server.ipaddress = "192.0.2.1"
        server.save!

        expect(User).to receive(:current_userid).and_return(request_user)
        expect(MiqRegion).to receive(:api_system_auth_token_for_region)
          .with(ApplicationRecord.my_region_number, request_user).and_return(region_auth_token)

        client_connection_hash = {
          :url      => "https://#{server.ipaddress}",
          :miqtoken => region_auth_token,
          :ssl      => {:verify => false}
        }
        expect(ManageIQ::API::Client).to receive(:new).with(client_connection_hash).and_return(api_connection)
        described_class.api_client_connection_for_region(ApplicationRecord.my_region_number)
      end

      it "raises if the server doesn't have an ip address" do
        expect {
          described_class.api_client_connection_for_region(ApplicationRecord.my_region_number)
        }.to raise_error(RuntimeError)
      end
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
