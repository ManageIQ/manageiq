#
# Rest API Request Tests - Service Catalogs specs
#
# - Creating single new service catalog   /api/service_catalogs                 POST
# - Creating single new service catalog   /api/service_catalogs                 action "add"
# - Creating multiple service catalogs    /api/service_catalogs                 action "add"
# - Edit a service catalog                /api/service_catalogs/:id             action "edit"
# - Edit multiple service catalogs        /api/service_catalogs                 action "edit"
# - Delete a service catalog              /api/service_catalogs/:id             DELETE
# - Delete a service catalog              /api/service_catalogs/:id             action "delete"
# - Delete service catalogs               /api/service_catalogs                 action "delete"
#
# - Assign service templates    /api/service_catalogs/:id/service_templates     action "assign"
# - Unassign service templates  /api/service_catalogs/:id/service_templates     action "unassign"
#
# - Order service               /api/service_catalogs/:id/service_templates/:id action "order"
# - Order services              /api/service_catalogs/:id/service_templates     action "order"
#
# - Refresh dialog fields       /api/service_catalogs/:id/service_templates/:id action "refresh_dialog_fields"
#
describe "Service Catalogs API" do
  def sc_templates_url(id, st_id = nil)
    st_base = "#{service_catalogs_url(id)}/service_templates"
    st_id ? "#{st_base}/#{st_id}" : st_base
  end

  describe "Service Catalogs create" do
    it "rejects resource creation without appropriate role" do
      api_basic_authorize

      run_post(service_catalogs_url, gen_request(:add, "name" => "sample service catalog"))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects resource creation via create action without appropriate role" do
      api_basic_authorize

      run_post(service_catalogs_url, "name" => "sample service catalog")

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects resource creation with id specified" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :add)

      run_post(service_catalogs_url, gen_request(:add, "name" => "sample service catalog", "id" => 100))

      expect_bad_request(/id or href should not be specified/i)
    end

    it "supports single resource creation" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :add)

      run_post(service_catalogs_url, gen_request(:add, "name" => "sample service catalog"))

      expect(response).to have_http_status(:ok)
      expected = {
        "results" => [
          a_hash_including(
            "id"   => kind_of(Integer),
            "name" => "sample service catalog"
          )
        ]
      }
      expect(response.parsed_body).to include(expected)

      sc_id = response.parsed_body["results"].first["id"]

      expect(ServiceTemplateCatalog.find(sc_id)).to be_truthy
    end

    it "supports single resource creation via create action" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :add)

      run_post(service_catalogs_url, "name" => "sample service catalog")

      expect(response).to have_http_status(:ok)
      expected = {
        "results" => [
          a_hash_including(
            "id"   => kind_of(Integer),
            "name" => "sample service catalog"
          )
        ]
      }
      expect(response.parsed_body).to include(expected)

      sc_id = response.parsed_body["results"].first["id"]

      expect(ServiceTemplateCatalog.find(sc_id)).to be_truthy
    end

    it "supports multiple resource creation" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :add)

      run_post(service_catalogs_url, gen_request(:add, [{"name" => "sc1"}, {"name" => "sc2"}]))

      expect(response).to have_http_status(:ok)
      expected = {
        "results" => a_collection_containing_exactly(
          a_hash_including("id" => kind_of(Integer), "name" => "sc1"),
          a_hash_including("id" => kind_of(Integer), "name" => "sc2")
        )
      }
      expect(response.parsed_body).to include(expected)

      results = response.parsed_body["results"]
      sc_id1, sc_id2 = results.first["id"], results.second["id"]
      expect(ServiceTemplateCatalog.find(sc_id1)).to be_truthy
      expect(ServiceTemplateCatalog.find(sc_id2)).to be_truthy
    end

    it "supports single resource creation with service templates" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :add)

      st1 = FactoryGirl.create(:service_template)
      st2 = FactoryGirl.create(:service_template)

      run_post(service_catalogs_url, gen_request(:add,
                                                 "name"              => "sc",
                                                 "description"       => "sc description",
                                                 "service_templates" => [
                                                   {"href" => service_templates_url(st1.id)},
                                                   {"href" => service_templates_url(st2.id)}
                                                 ]))

      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results", [{"name" => "sc", "description" => "sc description"}])

      sc_id = response.parsed_body["results"].first["id"]

      expect(ServiceTemplateCatalog.find(sc_id)).to be_truthy
      expect(ServiceTemplateCatalog.find(sc_id).service_templates.pluck(:id)).to match_array([st1.id, st2.id])
    end
  end

  describe "Service Catalogs edit" do
    it "rejects resource edits without appropriate role" do
      api_basic_authorize

      run_post(service_catalogs_url, gen_request(:edit, "name" => "sc1", "href" => service_catalogs_url(999_999)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects edits for invalid resources" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :edit)

      run_post(service_catalogs_url(999_999), gen_request(:edit, "description" => "updated sc description"))

      expect(response).to have_http_status(:not_found)
    end

    it "supports single resource edit" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :edit)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")

      run_post(service_catalogs_url(sc.id), gen_request(:edit, "description" => "updated sc description"))

      expected = {
        "service_templates" => a_hash_including(
          "actions" => a_collection_containing_exactly(
            a_hash_including(
              "name"   => "assign",
              "method" => "post",
            ),
            a_hash_including(
              "name"   => "unassign",
              "method" => "post",
            )
          )
        )
      }
      expect(response.parsed_body).to include(expected)
      expect_single_resource_query("id" => sc.id, "name" => "sc", "description" => "updated sc description")
      expect(sc.reload.description).to eq("updated sc description")
    end

    it "supports multiple resource edits" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :edit)

      sc1 = FactoryGirl.create(:service_template_catalog, :name => "sc1", :description => "sc1 description")
      sc2 = FactoryGirl.create(:service_template_catalog, :name => "sc2", :description => "sc2 description")

      run_post(service_catalogs_url, gen_request(:edit,
                                                 [{"href" => service_catalogs_url(sc1.id), "name" => "sc1 updated"},
                                                  {"href" => service_catalogs_url(sc2.id), "name" => "sc2 updated"}]))

      expect_results_to_match_hash("results",
                                   [{"id" => sc1.id, "name" => "sc1 updated", "description" => "sc1 description"},
                                    {"id" => sc2.id, "name" => "sc2 updated", "description" => "sc2 description"}])

      expect(sc1.reload.name).to eq("sc1 updated")
      expect(sc2.reload.name).to eq("sc2 updated")
    end
  end

  describe "Service Catalogs delete" do
    it "rejects deletion without appropriate role" do
      api_basic_authorize

      run_post(service_catalogs_url, gen_request(:delete, "name" => "sc1", "href" => service_catalogs_url(100)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects resource deletion without appropriate role" do
      api_basic_authorize

      run_delete(service_catalogs_url(100))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects resource deletes for invalid resources" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :delete)

      run_delete(service_catalogs_url(999_999))

      expect(response).to have_http_status(:not_found)
    end

    it "supports single resource deletes" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :delete)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")

      run_delete(service_catalogs_url(sc.id))

      expect(response).to have_http_status(:no_content)
      expect { sc.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "supports resource deletes via action" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :delete)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")

      run_post(service_catalogs_url(sc.id), gen_request(:delete))

      expect_single_action_result(:success => true, :message => "deleting", :href => service_catalogs_url(sc.id))
      expect { sc.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "supports multiple resource deletes" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :delete)

      sc1 = FactoryGirl.create(:service_template_catalog, :name => "sc1", :description => "sc1 description")
      sc2 = FactoryGirl.create(:service_template_catalog, :name => "sc2", :description => "sc2 description")

      run_post(service_catalogs_url, gen_request(:delete,
                                                 [{"href" => service_catalogs_url(sc1.id)},
                                                  {"href" => service_catalogs_url(sc2.id)}]))
      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", [service_catalogs_url(sc1.id), service_catalogs_url(sc2.id)])

      expect { sc1.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { sc2.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Service Catalogs service template assignments" do
    it "rejects assign requests without appropriate role" do
      api_basic_authorize

      run_post(sc_templates_url(100), gen_request(:assign, "href" => service_templates_url(1)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects unassign requests without appropriate role" do
      api_basic_authorize

      run_post(sc_templates_url(100), gen_request(:unassign, "href" => service_templates_url(1)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects assign requests with invalid service template" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :assign)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")

      run_post(sc_templates_url(sc.id), gen_request(:assign, "href" => service_templates_url(999_999)))

      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results", [{"success" => false, "href" => service_catalogs_url(sc.id)}])
    end

    it "supports assign requests" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :assign)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")
      st = FactoryGirl.create(:service_template)

      run_post(sc_templates_url(sc.id), gen_request(:assign, "href" => service_templates_url(st.id)))

      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results", [{"success"               => true,
                                                "href"                  => service_catalogs_url(sc.id),
                                                "service_template_id"   => st.id,
                                                "service_template_href" => /^.*#{service_templates_url(st.id)}$/,
                                                "message"               => /assigning/i}])
      expect(sc.reload.service_templates.pluck(:id)).to eq([st.id])
    end

    it "supports unassign requests" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :assign)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")
      st1 = FactoryGirl.create(:service_template)
      st2 = FactoryGirl.create(:service_template)
      sc.service_templates = [st1, st2]

      run_post(sc_templates_url(sc.id), gen_request(:unassign, "href" => service_templates_url(st1.id)))

      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results", [{"success"               => true,
                                                "href"                  => service_catalogs_url(sc.id),
                                                "service_template_id"   => st1.id,
                                                "service_template_href" => /^.*#{service_templates_url(st1.id)}$/,
                                                "message"               => /unassigning/i}])
      expect(sc.reload.service_templates.pluck(:id)).to eq([st2.id])
    end
  end

  describe "Service Catalogs service template ordering" do
    let(:order_request) do
      {"type"           => "ServiceTemplateProvisionRequest",
       "description"    => /provisioning service/i,
       "approval_state" => "pending_approval",
       "status"         => "Ok"}
    end

    let(:dialog1) { FactoryGirl.create(:dialog, :label => "Dialog1") }
    let(:tab1)    { FactoryGirl.create(:dialog_tab, :label => "Tab1") }
    let(:group1)  { FactoryGirl.create(:dialog_group, :label => "Group1") }
    let(:text1)   { FactoryGirl.create(:dialog_field_text_box, :label => "TextBox1", :name => "text1") }
    let(:ra1)     { FactoryGirl.create(:resource_action, :action => "Provision", :dialog => dialog1) }
    let(:st1)     { FactoryGirl.create(:service_template, :name => "service template 1", :display => true) }
    let(:ra2)     { FactoryGirl.create(:resource_action, :action => "Provision", :dialog => dialog1) }
    let(:st2)     { FactoryGirl.create(:service_template, :name => "service template 2", :display => true) }
    let(:sc)      { FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description") }

    def init_st(service_template, resource_action)
      service_template.resource_actions = [resource_action]
      dialog1.dialog_tabs << tab1
      tab1.dialog_groups << group1
      group1.dialog_fields << text1
    end

    it "does not return order action for non-orderable service templates" do
      api_basic_authorize(subcollection_action_identifier(:service_catalogs, :service_templates, :edit),
                          subcollection_action_identifier(:service_catalogs, :service_templates, :order))

      init_st(st1, ra1)
      sc.service_templates = [st1]

      st1.display = false
      st1.save

      run_get sc_templates_url(sc.id, st1.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to_not include_actions("order")
    end

    it "returns order action for orderable service templates" do
      api_basic_authorize(subcollection_action_identifier(:service_catalogs, :service_templates, :edit),
                          subcollection_action_identifier(:service_catalogs, :service_templates, :order))

      init_st(st1, ra1)
      sc.service_templates = [st1]

      run_get sc_templates_url(sc.id, st1.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include_actions("order")
    end

    it "rejects order requests without appropriate role" do
      api_basic_authorize

      run_post(sc_templates_url(100), gen_request(:order, "href" => service_templates_url(1)))

      expect(response).to have_http_status(:forbidden)
    end

    it "supports single order request" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :order)

      init_st(st1, ra1)
      sc.service_templates = [st1]

      run_post(sc_templates_url(sc.id, st1.id), gen_request(:order))

      expect_single_resource_query(order_request)
    end

    it "accepts order requests with required fields" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :order)

      text1.required = true
      init_st(st1, ra1)
      sc.service_templates = [st1]

      run_post(sc_templates_url(sc.id, st1.id), gen_request(:order, "text1" => "value1"))

      expect_single_resource_query(order_request)
    end

    it "rejects order requests without required fields" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :order)

      text1.required = true
      init_st(st1, ra1)
      sc.service_templates = [st1]

      run_post(sc_templates_url(sc.id, st1.id), gen_request(:order))

      expect_bad_request("Failed to order")
    end

    it "supports multiple order requests" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :order)

      init_st(st1, ra1)
      init_st(st2, ra2)
      sc.service_templates = [st1, st2]

      run_post(sc_templates_url(sc.id), gen_request(:order, [{"href" => service_templates_url(st1.id)},
                                                             {"href" => service_templates_url(st2.id)}]))
      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results", [order_request, order_request])
    end
  end

  describe "Service Catalogs service template refresh dialog fields" do
    let(:dialog1) { FactoryGirl.create(:dialog, :label => "Dialog1") }
    let(:tab1)    { FactoryGirl.create(:dialog_tab, :label => "Tab1") }
    let(:group1)  { FactoryGirl.create(:dialog_group, :label => "Group1") }
    let(:text1)   { FactoryGirl.create(:dialog_field_text_box, :label => "TextBox1", :name => "text1") }
    let(:ra1)     { FactoryGirl.create(:resource_action, :action => "Provision", :dialog => dialog1) }
    let(:st1)     { FactoryGirl.create(:service_template, :name => "service template 1") }
    let(:sc)      { FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description") }

    def init_st
      sc.service_templates = [st1]
      st1.resource_actions = [ra1]
    end

    def init_st_dialog
      init_st
      dialog1.dialog_tabs << tab1
      tab1.dialog_groups << group1
      group1.dialog_fields << text1
    end

    it "rejects refresh dialog fields requests without appropriate role" do
      api_basic_authorize

      run_post(sc_templates_url(sc.id, st1.id), gen_request(:refresh_dialog_fields, "fields" => %w(test1)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects refresh dialog fields with unspecified fields" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :refresh_dialog_fields)
      sc.service_templates = [st1]

      run_post(sc_templates_url(sc.id, st1.id), gen_request(:refresh_dialog_fields))

      expect_single_action_result(:success => false, :message => /must specify fields/i)
    end

    it "rejects refresh dialog fields of invalid fields" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :refresh_dialog_fields)
      init_st_dialog

      run_post(sc_templates_url(sc.id, st1.id), gen_request(:refresh_dialog_fields, "fields" => %w(bad_field)))

      expect_single_action_result(:success => false, :message => /unknown dialog field bad_field/i)
    end

    it "supports refresh dialog fields of valid fields" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :refresh_dialog_fields)
      init_st_dialog

      run_post(sc_templates_url(sc.id, st1.id), gen_request(:refresh_dialog_fields, "fields" => %w(text1)))

      expected = {
        "success"               => true,
        "message"               => a_string_matching(/refreshing dialog fields/i),
        "href"                  => anything,
        "service_template_id"   => anything,
        "service_template_href" => anything,
        "result"                => hash_including("text1")
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end
end
