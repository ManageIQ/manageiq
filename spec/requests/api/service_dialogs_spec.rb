#
# REST API Request Tests - Service Dialogs specs
#
# - Refresh dialog fields       /api/service_dialogs/:id "refresh_dialog_fields"
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

  describe "Service Dialogs refresh dialog fields" do
    let(:dialog1) { FactoryGirl.create(:dialog, :label => "Dialog1") }
    let(:tab1)    { FactoryGirl.create(:dialog_tab, :label => "Tab1") }
    let(:group1)  { FactoryGirl.create(:dialog_group, :label => "Group1") }
    let(:text1)   { FactoryGirl.create(:dialog_field_text_box, :label => "TextBox1", :name => "text1") }

    def init_dialog
      dialog1.dialog_tabs << tab1
      tab1.dialog_groups << group1
      group1.dialog_fields << text1
    end

    it "rejects refresh dialog fields requests without appropriate role" do
      api_basic_authorize

      run_post(service_dialogs_url(dialog1.id), gen_request(:refresh_dialog_fields, "fields" => %w(test1)))

      expect_request_forbidden
    end

    it "rejects refresh dialog fields with unspecified fields" do
      api_basic_authorize action_identifier(:service_dialogs, :refresh_dialog_fields)
      init_dialog

      run_post(service_dialogs_url(dialog1.id), gen_request(:refresh_dialog_fields))

      expect_single_action_result(:success => false, :message => /must specify fields/i)
    end

    it "rejects refresh dialog fields of invalid fields" do
      api_basic_authorize action_identifier(:service_dialogs, :refresh_dialog_fields)
      init_dialog

      run_post(service_dialogs_url(dialog1.id), gen_request(:refresh_dialog_fields, "fields" => %w(bad_field)))

      expect_single_action_result(:success => false, :message => /unknown dialog field bad_field/i)
    end

    it "supports refresh dialog fields of valid fields" do
      api_basic_authorize action_identifier(:service_dialogs, :refresh_dialog_fields)
      init_dialog

      run_post(service_dialogs_url(dialog1.id), gen_request(:refresh_dialog_fields, "fields" => %w(text1)))

      expect(response_hash).to include(
        "success" => true,
        "message" => a_string_matching(/refreshing dialog fields/i),
        "href"    => a_string_matching(service_dialogs_url(dialog1.id)),
        "result"  => hash_including("text1")
      )
    end
  end
end
