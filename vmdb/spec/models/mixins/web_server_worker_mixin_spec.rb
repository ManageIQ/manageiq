require 'spec_helper'

describe WebServerWorkerMixin do
  it "build_uri (ipv6)" do
    test_class = Class.new do
      include WebServerWorkerMixin
    end

    test_class.stub(:binding_address => "::1")
    expect(test_class.build_uri(123)).to eq "http://[::1]:123"
  end
end
