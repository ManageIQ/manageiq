require "spec_helper"

$LOAD_PATH.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. VMwareWebService})))
require 'MiqVimClientBase'

describe MiqVimClientBase do
  before do
    @logger  = $vim_log
    $vim_log = double.as_null_object
    described_class.any_instance.stub(:retrieveServiceContent => double.as_null_object)
  end

  after do
    $vim_log = @logger
  end

  context "#sdk_uri" do
    it "IPv4" do
      expect(described_class.new("127.0.0.1", nil, nil).sdk_uri.to_s).to eq "https://127.0.0.1/sdk"
    end

    it "delegates to URI to wrap IPv6 address in []" do
      expect(described_class.new("::1", nil, nil).sdk_uri.to_s).to eq "https://[::1]/sdk"
    end
  end
end
