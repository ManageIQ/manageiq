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

  it 'returns the correct href' do
    provider = FactoryGirl.create(:ext_management_system)
    custom_attribute = FactoryGirl.create(:custom_attribute, :resource => provider, :name => 'foo', :value => 'bar')
    url = "#{providers_url(provider.id)}/custom_attributes/#{custom_attribute.id}"
    api_basic_authorize subcollection_action_identifier(:providers, :custom_attributes, :edit, :post)

    run_post(url, :action => :edit, :name => 'name1')

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['href']).to include(url)
  end
end
