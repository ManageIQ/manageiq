describe ApiController do
  let(:ems) { FactoryGirl.create(:ext_management_system) }
  let(:virtual_template) { FactoryGirl.create(:virtual_template, :ems_id => ems.id) }
  let(:request) do
    {
      'vm_name' => 'VirtualTemplate',
      'requester' => {
        'owner_first_name' => 'First',
        'owner_last_name' => 'Last',
        'owner_email' => 'email@email.com',
        'request_notes' => 'A Test Provision'
      }
    }
  end

  describe 'Virtual Template Provision Request' do
    it 'provisions a virtual template' do
      # TODO: If this doesn't work, will need to change :virtual_templates to :template
      api_basic_authorize collection_action_identifier(:virtual_template_provision, :create)

      request_url = "#{virtual_templates_url(virtual_template.id)}/provision"
      run_post(request_url, request)

      expect(response).to have_http_status(:ok)
    end
  end
end