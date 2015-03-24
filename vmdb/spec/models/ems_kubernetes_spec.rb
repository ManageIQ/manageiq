require "spec_helper"

describe EmsKubernetes do
  it ".raw_api_endpoint (ipv6)" do
    expect(described_class.raw_api_endpoint("::1", 123).to_s).to eq "http://[::1]:123/api"
  end
end
