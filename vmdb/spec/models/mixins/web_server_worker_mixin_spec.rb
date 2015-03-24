require 'spec_helper'

describe WebServerWorkerMixin do
  it "build_uri (ipv6)" do
    class TestClass
      include WebServerWorkerMixin
    end

    TestClass.stub(:binding_address => "::1")
    expect(TestClass.build_uri(123)).to eq "http://[::1]:123"
  end
end
