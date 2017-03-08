RSpec.describe "Shared VMs API" do
  describe "GET /api/shared_vms" do
    it "returns the VMs that are shared with the requester" do
      sharee = create_sharee
      sharer = create_sharer
      vm = FactoryGirl.create(:vm_vmware, :miq_group => sharer.miq_groups.last)
      create_share(sharer, sharee, vm)
      api_basic_authorize

      run_get(shared_vms_url)

      expected = {
        "resources" => [
          {
            "href" => a_string_matching(shared_vms_url(vm.id)),
          }
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "does not return any non-VM resources" do
      sharee = create_sharee
      sharer = create_sharer
      template = FactoryGirl.create(:template_vmware, :miq_group => sharer.miq_groups.last)
      create_share(sharer, sharee, template)
      api_basic_authorize

      run_get(shared_vms_url)

      expect(response.parsed_body).to include("resources" => [])
      expect(response).to have_http_status(:ok)
    end

    it "can filter" do
      sharee = create_sharee
      sharer = create_sharer
      alice_vm = FactoryGirl.create(:vm_vmware, :name => "Alice's VM", :miq_group => sharer.miq_groups.last)
      bob_vm = FactoryGirl.create(:vm_vmware, :name => "Bob's VM", :miq_group => sharer.miq_groups.last)
      create_share(sharer, sharee, alice_vm)
      create_share(sharer, sharee, bob_vm)
      api_basic_authorize

      run_get(shared_vms_url, :filter => [%q(name="Alice's VM")])

      expected = {
        "resources" => [
          {
            "href" => a_string_matching(shared_vms_url(alice_vm.id)),
          }
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/shared_vms/:c_id" do
    it "shows the details of a VM that's shared with the requester" do
      sharee = create_sharee
      sharer = create_sharer
      vm = FactoryGirl.create(:vm_vmware, :miq_group => sharer.miq_groups.last, :name => "Alice's VM")
      create_share(sharer, sharee, vm)
      api_basic_authorize

      run_get(shared_vms_url(vm.id))

      expected = {
        "id"   => vm.id,
        "href" => a_string_matching(shared_vms_url(vm.id)),
        "name" => "Alice's VM"
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "responds with not found if the VM isn't shared with the requester" do
      _sharee = create_sharee
      sharer = create_sharer
      vm = FactoryGirl.create(:vm_vmware, :miq_group => sharer.miq_groups.last, :name => "Alice's VM")
      api_basic_authorize

      run_get(shared_vms_url(vm.id))

      expect(response).to have_http_status(:not_found)
    end
  end

  def create_sharee
    sharee = @user
    sharee_group = @group
    sharee_tenant = FactoryGirl.create(:tenant)
    sharee_group.tenant = sharee_tenant
    sharee_group.save!
    sharee
  end

  def create_sharer
    everything = FactoryGirl.create(:miq_product_feature_everything)
    sharer_role = FactoryGirl.create(:miq_user_role, :features => [everything])
    sharer_tenant = FactoryGirl.create(:tenant)
    sharer_group = FactoryGirl.create(:miq_group, :role => sharer_role, :features => [everything], :tenant => sharer_tenant)
    sharer = FactoryGirl.create(:user, :miq_groups => [sharer_group])
    sharer
  end

  def create_share(sharer, sharee, resource)
    ResourceSharer.new(:user => sharer,
                       :tenants => [sharee.current_tenant],
                       :resource => resource,
                       :features => sharer.miq_groups.last.entitlement.miq_user_role.miq_product_features).share
  end
end
