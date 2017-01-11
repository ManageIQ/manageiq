RSpec.describe "Snapshots API" do
  describe "as a subcollection of VMs" do
    describe "GET /api/vms/:c_id/snapshots" do
      it "can list the snapshots of a VM" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :read, :get))
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)
        _other_snapshot = FactoryGirl.create(:snapshot)

        run_get("#{vms_url(vm.id)}/snapshots")

        expected = {
          "count"     => 2,
          "name"      => "snapshots",
          "subcount"  => 1,
          "resources" => [
            {"href" => a_string_matching("#{vms_url(vm.id)}/snapshots/#{snapshot.id}")}
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not list snapshots unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)
        FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_get("#{vms_url(vm.id)}/snapshots")

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
