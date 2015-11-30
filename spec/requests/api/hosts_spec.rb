require "spec_helper"

RSpec.describe "hosts API" do
  include Rack::Test::Methods

  before { init_api_spec_env }

  def app
    Vmdb::Application
  end

  describe "editing a host's password" do
    context "with an appropriate role" do
      it "can edit the password on a host" do
        host = FactoryGirl.create(:host_with_authentication)
        api_basic_authorize action_identifier(:hosts, :edit)
        options = {:credentials => {:authtype => "default", :password => "abc123"}}

        expect do
          run_post hosts_url(host.id), gen_request(:edit, options)
        end.to change { host.reload.authentication_password(:default) }.to("abc123")
        expect_request_success
      end

      it "will update the default authentication if no type is given" do
        host = FactoryGirl.create(:host_with_authentication)
        api_basic_authorize action_identifier(:hosts, :edit)
        options = {:credentials => {:password => "abc123"}}

        expect do
          run_post hosts_url(host.id), gen_request(:edit, options)
        end.to change { host.reload.authentication_password(:default) }.to("abc123")
        expect_request_success
      end
    end

    context "without an appropriate role" do
      it "cannot edit the password on a host" do
        host = FactoryGirl.create(:host_with_authentication)
        api_basic_authorize
        options = {:credentials => {:authtype => "default", :password => "abc123"}}

        expect do
          run_post hosts_url(host.id), gen_request(:edit, options)
        end.not_to change { host.reload.authentication_password(:default) }
        expect_request_forbidden
      end
    end
  end
end
