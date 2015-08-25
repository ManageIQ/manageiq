require "spec_helper"

describe ManageIQ::Providers::Kubernetes::ContainerManager do
  it ".raw_api_endpoint (ipv6)" do
    expect(described_class.raw_api_endpoint("::1", 123).to_s).to eq "https://[::1]:123"
  end
end
