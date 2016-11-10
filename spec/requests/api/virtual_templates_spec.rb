#
# REST API Request Tests - Virtual Template Specs
#
# - Get list of virtual templates             /api/virtual_templates                GET
# - Get a virtual template                    /api/virtual_templates/:id            GET

RSpec.describe 'Virtual Template API' do
  let(:cloud_subnet) { FactoryGirl.create(:cloud_subnet) }
  let(:cloud_network) { FactoryGirl.create(:cloud_network) }
  let(:availability_zone) { FactoryGirl.create(:availability_zone_google) }
  let(:ems) { FactoryGirl.create(:ext_management_system) }
  let(:flavor) { FactoryGirl.create(:flavor_google) }

  context 'virtual templates index' do
    it 'can list all the virtual templates' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :read, :get)
      FactoryGirl.create(:virtual_template, :ems_id => ems.id)
      FactoryGirl.create(:virtual_template_google,
                         :ems_id               => ems.id,
                         :flavor_id            => flavor.id,
                         :cloud_network_id     => cloud_network.id,
                         :cloud_subnet_id      => cloud_subnet.id,
                         :availability_zone_id => availability_zone.id)

      run_get(virtual_templates_url)
      expect_query_result(:virtual_templates, 2, 2)
    end

    it 'only lists virtual templates (no other templates)' do
      api_basic_authorize collection_action_identifier(:virtual_templates, :read, :get)
      FactoryGirl.create(:virtual_template, :ems_id => ems.id)
      FactoryGirl.create(:template_google, :ems_id => ems.id)

      run_get(virtual_templates_url)
      expect_query_result(:virtual_templates, 1, 1)
    end
  end

  context 'virtual templates get' do
    it "rejects resource get requests without appropriate role" do
      api_basic_authorize

      vt = FactoryGirl.create(:virtual_template, :ems_id => ems.id)

      run_get(virtual_templates_url(vt.id))

      expect(response).to have_http_status(:forbidden)
    end

    it "accepts resource get requests with appropriate role" do
      api_basic_authorize action_identifier(:virtual_templates, :read, :resource_actions, :get)

      vt = FactoryGirl.create(:virtual_template, :ems_id => ems.id)

      run_get(virtual_templates_url(vt.id))

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(id href))
    end
  end
end
