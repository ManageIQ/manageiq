require "spec_helper"

require 'util/extensions/miq-uri'

describe URI::Generic do
  it "hash" do
    expect(described_class.build(
      :host => "::1",
      :scheme => "http",
      :port => 123,
      :path => "/api"
    ).to_s).to eq "http://[::1]:123/api"
  end

  it "array" do
    expect(described_class.build(
      # [scheme, userinfo, host, port, registry, path, opaque, query, fragment]
      ["http", nil, "::1", 123, nil, "/api", nil,  nil, nil]
    ).to_s).to eq "http://[::1]:123/api"
  end
end

describe URI::HTTPS do
  it "hash" do
    expect(described_class.build(
      :host => "::1",
      :port => 123,
      :path => "/api"
    ).to_s).to eq "https://[::1]:123/api"
  end

  it "array" do
    expect(described_class.build(
      # [userinfo, host, port, path, query, fragment]
      [nil, "::1", 123, "/api", nil, nil]
    ).to_s).to eq "https://[::1]:123/api"
  end
end
