RSpec.describe "guest devices API" do
  describe "display guest device details" do
    context "with a valid role" do
      it "shows its properties" do
        device = FactoryGirl.create(:guest_device,
                                    :device_name => "Broadcom 2-port 1GbE NIC Card",
                                    :device_type => "ethernet",
                                    :location    => "Bay 7")

        api_basic_authorize action_identifier(:guest_devices, :read, :resource_actions, :get)

        run_get(guest_devices_url(device.id))

        expect_single_resource_query("device_name" => "Broadcom 2-port 1GbE NIC Card",
                                     "device_type" => "ethernet",
                                     "location"    => "Bay 7")
      end
    end

    context "with an invalid role" do
      it "fails to show its properties" do
        device = FactoryGirl.create(:guest_device)

        api_basic_authorize

        run_get(guest_devices_url(device.id))

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
