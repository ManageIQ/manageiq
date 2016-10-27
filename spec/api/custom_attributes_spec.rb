RSpec.describe "Custom Attributes API" do
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
