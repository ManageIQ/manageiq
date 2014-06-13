require "spec_helper"

describe ProviderObjectMixin do
  before do
    class TestClass
      include ProviderObjectMixin
    end
  end

  after do
    Object.send(:remove_const, "TestClass")
  end

  def mock_ems_with_connection
    @ems        = mock("ems")
    @connection = mock("connection")
    @ems.should_receive(:with_provider_connection).and_yield(@connection)
    TestClass.any_instance.stub(:ext_management_system => @ems)
  end

  it "#with_provider_connection" do
    mock_ems_with_connection
    expect { |b| TestClass.new.with_provider_connection(&b) }.to yield_with_args(@connection)
  end

  context "when provider_object is written" do
    before do
      @provider_object = mock("provider_object")
      TestClass.any_instance.stub(:provider_object => @provider_object)
    end

    it "#provider_object" do
      expect { TestClass.new.provider_object(@connection) }.to_not raise_error
    end

    it "#with_provider_object" do
      mock_ems_with_connection
      expect { |b| TestClass.new.with_provider_object(&b) }.to yield_with_args(@provider_object)
    end
  end

  context "when provider_object is not written" do
    it "#provider_object" do
      expect { TestClass.new.provider_object(@connection) }.to raise_error(NotImplementedError)
    end

    it "#with_provider_object" do
      mock_ems_with_connection
      expect { TestClass.new.with_provider_object {} }.to raise_error(NotImplementedError)
    end
  end
end
