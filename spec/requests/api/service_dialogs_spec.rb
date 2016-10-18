#
# REST API Request Tests - Service Dialogs specs
#
# - Refresh dialog fields       /api/service_dialogs/:id "refresh_dialog_fields"
#
describe "Service Dialogs API" do
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
    before { template.resource_actions = [ra1, ra2] }

    it "query only returns href" do
      api_basic_authorize collection_action_identifier(:service_dialogs, :read, :get)
      run_get service_dialogs_url

      expected = {
        "name"      => "service_dialogs",
        "count"     => Dialog.count,
        "subcount"  => Dialog.count,
        "resources" => Array.new(Dialog.count) { {"href" => anything} }
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "query with expanded resources to include content" do
      api_basic_authorize collection_action_identifier(:service_dialogs, :read, :get)
      run_get service_dialogs_url, :expand => "resources"

      expect_query_result(:service_dialogs, Dialog.count, Dialog.count)
      expect_result_resources_to_include_keys("resources", %w(id href label content))
    end

    it "query single dialog to include content" do
      api_basic_authorize action_identifier(:service_dialogs, :read, :resource_actions, :get)
      run_get service_dialogs_url(dialog1.id)

      expect_single_resource_query(
        "id"    => dialog1.id,
        "href"  => service_dialogs_url(dialog1.id),
        "label" => dialog1.label
      )
      expect_result_to_have_keys(%w(content))
    end

    it "query single dialog to exclude content when attributes are asked for" do
      api_basic_authorize action_identifier(:service_dialogs, :read, :resource_actions, :get)

      run_get service_dialogs_url(dialog1.id), :attributes => "id,label"

      expect_result_to_have_only_keys(%w(href id label))
    end

    context 'Delete Service Dialogs' do
      it 'DELETE /api/service_dialogs/:id' do
        dialog = FactoryGirl.create(:dialog)
        api_basic_authorize collection_action_identifier(:service_dialogs, :delete)

        expect do
          run_delete(service_dialogs_url(dialog.id))
        end.to change(Dialog, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end

      it 'POST /api/service_dialogs/:id deletes a single service dialog' do
        dialog = FactoryGirl.create(:dialog)
        api_basic_authorize collection_action_identifier(:service_dialogs, :delete)

        expect do
          run_post(service_dialogs_url(dialog.id), 'action' => 'delete')
        end.to change(Dialog, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      it 'POST /api/service_dialogs deletes a single service dialog' do
        dialog = FactoryGirl.create(:dialog)
        api_basic_authorize collection_action_identifier(:service_dialogs, :delete)

        expect do
          run_post(service_dialogs_url, 'action' => 'delete', 'resources' => [{ 'id' => dialog.id }])
        end.to change(Dialog, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      it 'POST /api/service_dialogs deletes multiple service dialogs' do
        dialog_a, dialog_b = FactoryGirl.create_list(:dialog, 2)
        api_basic_authorize collection_action_identifier(:service_dialogs, :delete)

        expect do
          run_post(service_dialogs_url, 'action'    => 'delete',
                                        'resources' => [{'id' => dialog_a.id}, {'id' => dialog_b.id}])
        end.to change(Dialog, :count).by(-2)
        expect(response).to have_http_status(:ok)
      end
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

    it "queries service dialogs content with the template and related resource action specified" do
      expect_any_instance_of(Dialog).to receive(:content).with(template, ra1, true)

      run_get "#{service_templates_url(template.id)}/service_dialogs/#{dialog1.id}", :attributes => "content"

      expect(response).to have_http_status(:ok)
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

      expect(response).to have_http_status(:forbidden)
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

      expect(response.parsed_body).to include(
        "success" => true,
        "message" => a_string_matching(/refreshing dialog fields/i),
        "href"    => a_string_matching(service_dialogs_url(dialog1.id)),
        "result"  => hash_including("text1")
      )
    end
  end

  context 'Creates service dialogs' do
    let(:dialog_request) do
      {
        :description => 'Dialog',
        :label       => 'dialog_label',
        :dialog_tabs => [
          {
            :description   => 'Dialog tab',
            :position      => 0,
            :label         => 'dialog_tab_label',
            :dialog_groups => [
              {
                :description   => 'Dialog group',
                :label         => 'group_label',
                :dialog_fields => [
                  {
                    :name  => 'A dialog field',
                    :label => 'dialog_field_label'
                  }
                ]
              }
            ]
          }
        ]
      }
    end

    it 'rejects service dialog creation without appropriate role' do
      api_basic_authorize

      run_post(service_dialogs_url, dialog_request)

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects service dialog creation with an href specified' do
      api_basic_authorize collection_action_identifier(:service_dialogs, :create)

      run_post(service_dialogs_url, dialog_request.merge!("href" => service_dialogs_url(123)))
      expected = {
        "error" => a_hash_including(
          "kind"    => "bad_request",
          "message" => a_string_matching(/id or href should not be specified/)
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects service dialog creation with an id specified' do
      api_basic_authorize collection_action_identifier(:service_dialogs, :create)

      run_post(service_dialogs_url, dialog_request.merge!("id" => 123))
      expected = {
        "error" => a_hash_including(
          "kind"    => "bad_request",
          "message" => a_string_matching(/id or href should not be specified/)
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:bad_request)
    end

    it 'supports single service dialog creation' do
      api_basic_authorize collection_action_identifier(:service_dialogs, :create)

      expected = {
        "results" => [
          a_hash_including(
            "description" => "Dialog",
            "label"       => "dialog_label"
          )
        ]
      }

      expect do
        run_post(service_dialogs_url, dialog_request)
      end.to change(Dialog, :count).by(1)
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'supports multiple service dialog creation' do
      api_basic_authorize collection_action_identifier(:service_dialogs, :create)
      dialog_request_2 = {
        :description => 'Dialog 2',
        :label       => 'dialog_2_label',
        :dialog_tabs => [
          {
            :description   => 'Dialog 2 tab',
            :position      => 0,
            :label         => 'dialog_2_label',
            :dialog_groups => [
              {
                :description   => 'a new dialog group',
                :label         => 'dialog_2_group_label',
                :dialog_fields => [
                  {
                    :name  => 'a new dialog field',
                    :label => 'dialog_field_label'
                  }
                ]
              }
            ]
          }
        ]
      }

      expected = {
        "results" => [
          a_hash_including(
            "description" => "Dialog",
            "label"       => "dialog_label"
          ),
          a_hash_including(
            "description" => "Dialog 2",
            "label"       => "dialog_2_label"
          )
        ]
      }

      expect do
        run_post(service_dialogs_url, gen_request(:create, [dialog_request, dialog_request_2]))
      end.to change(Dialog, :count).by(2)
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'returns dialog import service errors' do
      api_basic_authorize collection_action_identifier(:service_dialogs, :create)
      invalid_request = {
        'description' => 'Dialog',
        'label'       => 'a_dialog'
      }

      expected = {
        'error' => a_hash_including(
          'kind'    => 'bad_request',
          'message' => a_string_including('Failed to create a new dialog'),
          'klass'   => 'Api::BadRequestError'
        )
      }

      expect do
        run_post(service_dialogs_url, invalid_request)
      end.to change(Dialog, :count).by(0)
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:bad_request)
    end
  end
end
