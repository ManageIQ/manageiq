RSpec.describe "physical_servers API" do
  describe "display a physical server's details" do
    context "with valid properties" do
      it "will show all of its properties" do
        FactoryGirl.create(:physical_server)

        api_basic_authorize

        run_get "/api/physical_servers/1"

        expect_single_resource_query("id" => 1)
        expect_single_resource_query("ems_id" => 1)
        expect_single_resource_query("name" => "physical_server")
        expect_single_resource_query("type" => "ManageIQ::Providers::Lenovo::PhysicalInfraManager::PhysicalServer")
        expect_single_resource_query("ems_ref" => "A59D5B36821111E1A9F5E41F13ED4F6A")
        expect_single_resource_query("created_at" => "2017-04-05T16:53:31Z")
        expect_single_resource_query("updated_at" => "2017-04-05T16:53:31Z")
        expect_single_resource_query("hostname" => "IMM-e41f13ed4f6f")
        expect_single_resource_query("product_name" => "System x3550 M4")
        expect_single_resource_query("manufacturer" => "IBM")
        expect_single_resource_query("machine_type" => "7914")
        expect_single_resource_query("model" => "AC1")
        expect_single_resource_query("serial_number" => "06ARFA2")
        expect_single_resource_query("vendor" => "lenovo")
        expect_single_resource_query("health_state" => "Valid")
        expect_single_resource_query("power_state" => "on")
        expect_single_resource_query("location_led_state" => "On")
      end
    end
  end
  
  describe "power on/off a physical server" do
    context "with valid action names" do
      it "creates a valid power on request" do
        request = gen_request(:power_on)
        
        expect(request).to eq({"action" => "power_on"})
      end

      it "creates a valid power off request" do
        request = gen_request(:power_off)
        
        expect(request).to eq({"action" => "power_off"})
      end

      it "creates a valid restart request" do
        request = gen_request(:restart)
        
        expect(request).to eq({"action" => "restart"})
      end
    end
  end

  describe "turn on/off a physical server's location LED" do
    context "with valid action names" do
      it "creates a valid turn on location LED request" do
        request = gen_request(:turn_on_loc_led)
        
        expect(request).to eq({"action" => "turn_on_loc_led"})
      end

      it "creates a valid turn off location LED request" do
        request = gen_request(:turn_off_loc_led)
        
        expect(request).to eq({"action" => "turn_off_loc_led"})
      end

      it "creates a valid blink location LED request" do
        request = gen_request(:blink_loc_led)
        
        expect(request).to eq({"action" => "blink_loc_led"})
      end
    end
  end
end
