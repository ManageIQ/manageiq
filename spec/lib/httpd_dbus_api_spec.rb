require 'webmock/rspec'
require 'httpd_dbus_api'

RSpec.describe HttpdDBusApi do
  let(:jdoe_userid) { "jdoe" }

  let(:jdoe_user_attrs) do
    {
      "mail"        => "jdoe@acme.com",
      "givenname"   => "John",
      "sn"          => "Doe",
      "displayname" => "John Doe",
      "domainname"  => "acme.com"
    }
  end

  let(:jdoe_user_groups) { %w(evmgroup-super_administrator evmgroup-user) }

  let(:jim_userid)       { "jim" }
  let(:jim_attrs_error)  { "Unable to get attributes for user #{jim_userid} - No such user" }
  let(:jim_groups_error) { "Unable to get groups for user #{jim_userid} - No such user" }

  before do
    ENV["HTTPD_DBUS_API_SERVICE_HOST"] = "1.2.3.4"
    ENV["HTTPD_DBUS_API_SERVICE_PORT"] = "3400"

    stub_request(:get, "http://1.2.3.4:3400/api/user_attrs/#{jdoe_userid}")
      .to_return(:status => 200, :body => { "result" => jdoe_user_attrs }.to_json)

    stub_request(:get, "http://1.2.3.4:3400/api/user_attrs/#{jdoe_userid}?attributes=givenname,sn")
      .to_return(:status => 200, :body => { "result" => jdoe_user_attrs.slice("givenname", "sn") }.to_json)

    stub_request(:get, "http://1.2.3.4:3400/api/user_attrs/#{jim_userid}")
      .to_return(:status => 400, :body => { "error" => jim_attrs_error }.to_json)

    stub_request(:get, "http://1.2.3.4:3400/api/user_groups/#{jdoe_userid}")
      .to_return(:status => 200, :body => { "result" => jdoe_user_groups }.to_json)

    stub_request(:get, "http://1.2.3.4:3400/api/user_groups/#{jim_userid}")
      .to_return(:status => 400, :body => { "error" => jim_groups_error }.to_json)
  end

  context "user_attrs" do
    it "returns the result section of the response" do
      expect(described_class.new.user_attrs(jdoe_userid)).to match(jdoe_user_attrs)
    end

    it "converts attribute list to comma separated attributes parameter" do
      expect(described_class.new.user_attrs(jdoe_userid, %w(givenname sn)))
        .to match(jdoe_user_attrs.slice("givenname", "sn"))
    end

    it "properly raises error messages" do
      expect { described_class.new.user_attrs(jim_userid) }.to raise_error(jim_attrs_error)
    end
  end

  context "user_groups" do
    it "returns the result section of the response" do
      expect(described_class.new.user_groups(jdoe_userid)).to match(jdoe_user_groups)
    end

    it "properly raises error messages" do
      expect { described_class.new.user_groups(jim_userid) }.to raise_error(jim_groups_error)
    end
  end
end
