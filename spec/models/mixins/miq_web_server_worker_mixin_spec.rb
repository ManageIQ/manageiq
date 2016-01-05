require 'spec_helper'

describe MiqWebServerWorkerMixin do
  it "build_uri (ipv6)" do
    test_class = Class.new do
      include MiqWebServerWorkerMixin
    end

    allow(test_class).to receive_messages(:binding_address => "::1")
    expect(test_class.build_uri(123)).to eq "http://[::1]:123"
  end

  it "#worker_options" do
    w = FactoryGirl.create(:miq_ui_worker, :uri => "http://127.0.0.1:3000")
    expect(w.worker_options).to eq(:guid => w.guid, :Port => 3000)
  end
end
