#
# REST API Request Tests - Service Dialogs specs
#
describe ApiController do
  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)        { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)       { FactoryGirl.create(:host) }

  let(:dialog1)    { FactoryGirl.create(:dialog, :label => "ServiceDialog1") }
  let(:dialog2)    { FactoryGirl.create(:dialog, :label => "ServiceDialog2") }

  let(:ra1)        { FactoryGirl.create(:resource_action, :dialog => dialog1) }
  let(:ra2)        { FactoryGirl.create(:resource_action, :dialog => dialog2) }

  let(:template)   { FactoryGirl.create(:service_template, :name => "ServiceTemplate") }
  let(:service)    { FactoryGirl.create(:service, :name => "Service1") }

  context "Service Dialogs collection" do
    before do
      template.resource_actions = [ra1, ra2]
      api_basic_authorize
    end

    it "query only returns href" do
      run_get service_dialogs_url

      expect_query_result(:service_dialogs, Dialog.count, Dialog.count)
      expect_result_resources_to_have_only_keys("resources", %w(href))
    end

    it "query with expanded resources to include content" do
      run_get service_dialogs_url, :expand => "resources"

      expect_query_result(:service_dialogs, Dialog.count, Dialog.count)
      expect_result_resources_to_include_keys("resources", %w(id href label content))
    end

    it "query single dialog to include content" do
      run_get service_dialogs_url(dialog1.id)

      expect_single_resource_query(
        "id"    => dialog1.id,
        "href"  => service_dialogs_url(dialog1.id),
        "label" => dialog1.label
      )
      expect_result_to_have_keys(%w(content))
    end

    it "query single dialog to exclude content when attributes are asked for" do
      run_get service_dialogs_url(dialog1.id), :attributes => "id,label"

      expect_result_to_have_only_keys(%w(href id label))
    end
  end

  context "Service Dialogs subcollection" do
    before do
      template.resource_actions = [ra1, ra2]
      api_basic_authorize
    end

    it "query all service dialogs of a Service Template" do
      run_get "#{service_templates_url(template.id)}/service_dialogs", :expand => "resources"

      dialogs = template.dialogs
      expect_query_result(:service_dialogs, dialogs.count, dialogs.count)
      expect_result_resources_to_include_data("resources", "label" => dialogs.pluck(:label))
    end

    it "query all service dialogs of a Service" do
      service.update_attributes!(:service_template_id => template.id)

      run_get "#{services_url(service.id)}/service_dialogs", :expand => "resources"

      dialogs = service.dialogs
      expect_query_result(:service_dialogs, dialogs.count, dialogs.count)
      expect_result_resources_to_include_data("resources", "label" => dialogs.pluck(:label))
    end
  end
end
