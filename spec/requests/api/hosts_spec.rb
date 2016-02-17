RSpec.describe "hosts API" do
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

      it "sending non-credentials attributes will result in a bad request error" do
        host = FactoryGirl.create(:host_with_authentication)
        api_basic_authorize action_identifier(:hosts, :edit)
        options = {:name => "new name"}

        expect do
          run_post hosts_url(host.id), gen_request(:edit, options)
        end.not_to change { host.reload.name }
        expect_bad_request
      end

      it "can update passwords on multiple hosts by href" do
        host1 = FactoryGirl.create(:host_with_authentication)
        host2 = FactoryGirl.create(:host_with_authentication)
        api_basic_authorize action_identifier(:hosts, :edit)
        options = [
          {:href => hosts_url(host1.id), :credentials => {:password => "abc123"}},
          {:href => hosts_url(host2.id), :credentials => {:password => "def456"}}
        ]

        run_post hosts_url, gen_request(:edit, options)
        expect_request_success
        expect(host1.reload.authentication_password(:default)).to eq("abc123")
        expect(host2.reload.authentication_password(:default)).to eq("def456")
      end

      it "can update passwords on multiple hosts by id" do
        host1 = FactoryGirl.create(:host_with_authentication)
        host2 = FactoryGirl.create(:host_with_authentication)
        api_basic_authorize action_identifier(:hosts, :edit)
        options = [
          {:id => host1.id, :credentials => {:password => "abc123"}},
          {:id => host2.id, :credentials => {:password => "def456"}}
        ]

        run_post hosts_url, gen_request(:edit, options)
        expect_request_success
        expect(host1.reload.authentication_password(:default)).to eq("abc123")
        expect(host2.reload.authentication_password(:default)).to eq("def456")
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
