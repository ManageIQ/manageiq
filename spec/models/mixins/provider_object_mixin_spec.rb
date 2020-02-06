RSpec.describe ProviderObjectMixin do
  let(:test_class) do
    Class.new do
      include ProviderObjectMixin
      attr_accessor :ext_management_system
    end
  end

  def mock_ems_with_connection
    @ems        = double("ems")
    @connection = double("connection")
    expect(@ems).to receive(:with_provider_connection).and_yield(@connection)
    allow_any_instance_of(test_class).to receive_messages(:ext_management_system => @ems)
  end

  it "#with_provider_connection" do
    mock_ems_with_connection
    expect { |b| test_class.new.with_provider_connection(&b) }.to yield_with_args(@connection)
  end

  context "when provider_object is written" do
    before do
      @provider_object = double("provider_object")
      allow_any_instance_of(test_class).to receive_messages(:provider_object => @provider_object)
    end

    it "#provider_object" do
      expect { test_class.new.provider_object(@connection) }.to_not raise_error
    end

    it "#with_provider_object" do
      mock_ems_with_connection
      expect { |b| test_class.new.with_provider_object(&b) }.to yield_with_args(@provider_object)
    end
  end

  context "when provider_object is not written" do
    it "#provider_object" do
      expect { test_class.new.provider_object(@connection) }.to raise_error(NotImplementedError)
    end

    it "#with_provider_object" do
      mock_ems_with_connection
      expect { test_class.new.with_provider_object {} }.to raise_error(NotImplementedError)
    end
  end

  context "when no ems or manager is available" do
    it "#connection_source" do
      expect { test_class.new.send(:connection_source) }.to raise_error(RuntimeError)
    end
  end
end
