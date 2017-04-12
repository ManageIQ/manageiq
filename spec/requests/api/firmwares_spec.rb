RSpec.describe "firmwares API" do
  describe "display firmware details" do
    context "with valid properties" do
      it "shows its properties" do
        FactoryGirl.create(:firmware, :id => 1, :name => "UEFI",
                           :version => "D7E152CUS-2.11", :resource_id => 1)

        api_basic_authorize action_identifier(:firmwares, :read, :resource_actions, :get)

        run_get "/api/firmwares/1"

        expect_single_resource_query("id" => 1)
        expect_single_resource_query("name" => "UEFI")
        expect_single_resource_query("version" => "D7E152CUS-2.11")
        expect_single_resource_query("resource_id" => 1)
      end
    end
  end
end
