RSpec.describe "physical_servers API" do
  describe "display a physical server's details" do
    context "with valid properties" do
      it "shows all of its properties" do
        ps = FactoryGirl.create(:physical_server, :ems_ref => "A59D5B36821111E1A9F5E41F13ED4F6A")

        api_basic_authorize action_identifier(:physical_servers, :read, :resource_actions, :get)
        run_get physical_servers_url(ps.id)

        expect_single_resource_query("ems_ref" => "A59D5B36821111E1A9F5E41F13ED4F6A")
      end
    end
  end

  describe "power on/off a physical server" do
    context "with valid action names" do
      it "powers on a server successfully" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize action_identifier(:physical_servers, :power_on, :resource_actions, :post)
        run_post(physical_servers_url(ps.id), gen_request(:power_on))

        expect(response).to have_http_status(:success)
      end

      it "powers off a server successfully" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize action_identifier(:physical_servers, :power_off, :resource_actions, :post)
        run_post(physical_servers_url(ps.id), gen_request(:power_off))

        expect(response).to have_http_status(:success)
      end

      it "restarts a server successfully" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize action_identifier(:physical_servers, :restart, :resource_actions, :post)
        run_post(physical_servers_url(ps.id), gen_request(:restart))

        expect(response).to have_http_status(:success)
      end
    end

    context "without an appropriate role" do
      it "fails to power on a server" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize
        run_post(physical_servers_url(ps.id), gen_request(:power_on))

        expect(response).to have_http_status(:forbidden)
      end

      it "fails to power off a server" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize
        run_post(physical_servers_url(ps.id), gen_request(:power_off))

        expect(response).to have_http_status(:forbidden)
      end

      it "fails to restart a server" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize
        run_post(physical_servers_url(ps.id), gen_request(:restart))

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "turn on/off a physical server's location LED" do
    context "with valid action names" do
      it "turns on a location LED successfully" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize action_identifier(:physical_servers, :turn_on_loc_led, :resource_actions, :post)
        run_post(physical_servers_url(ps.id), gen_request(:turn_on_loc_led))

        expect(response).to have_http_status(:success)
      end

      it "turns off a location LED successfully" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize action_identifier(:physical_servers, :turn_off_loc_led, :resource_actions, :post)
        run_post(physical_servers_url(ps.id), gen_request(:turn_off_loc_led))

        expect(response).to have_http_status(:success)
      end

      it "blinks a location LED successfully" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize action_identifier(:physical_servers, :blink_loc_led, :resource_actions, :post)
        run_post(physical_servers_url(ps.id), gen_request(:blink_loc_led))

        expect(response).to have_http_status(:success)
      end
    end

    context "without an appropriate role" do
      it "fails to turn on a location LED" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize
        run_post(physical_servers_url(ps.id), gen_request(:turn_on_loc_led))

        expect(response).to have_http_status(:forbidden)
      end

      it "fails to turn off a location LED" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize
        run_post(physical_servers_url(ps.id), gen_request(:turn_off_loc_led))

        expect(response).to have_http_status(:forbidden)
      end

      it "fails to blink a location LED" do
        ps = FactoryGirl.create(:physical_server)

        api_basic_authorize
        run_post(physical_servers_url(ps.id), gen_request(:blink_loc_led))

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
