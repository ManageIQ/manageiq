RSpec.describe "Custom Attributes API" do
  describe "GET /api/<collection>/:cid/custom_attributes/:sid" do
    it "renders the actions available on custom attribute members" do
      vm = FactoryGirl.create(:vm_vmware)
      custom_attribute = FactoryGirl.create(:custom_attribute, :resource => vm)
      api_basic_authorize

      run_get("#{vms_url(vm.id)}/custom_attributes/#{custom_attribute.id}")

      expected = {
        "actions" => a_collection_including(
          a_hash_including("name" => "edit", "method" => "post"),
          a_hash_including("name" => "delete", "method" => "post"),
          a_hash_including("name" => "delete", "method" => "delete")
        )
      }
      expect(response.parsed_body).to include(expected)
    end
  end

  it "can delete a custom attribute through its nested URI" do
    vm = FactoryGirl.create(:vm_vmware)
    custom_attribute = FactoryGirl.create(:custom_attribute, :resource => vm)
    api_basic_authorize

    expect do
      run_delete("#{vms_url(vm.id)}/custom_attributes/#{custom_attribute.id}")
    end.to change(CustomAttribute, :count).by(-1)

    expect(response).to have_http_status(:no_content)
  end
end
