#
# Rest API Request Tests - Service Templates specs
#
# - Edit service template               /api/service_templates/:id    action "edit"
# - Edit multiple service templates     /api/service_templates        action "edit"
# - Delete service template             /api/service_templates/:id    DELETE
# - Delete multiple service templates   /api/service_templates        action "delete"
#
describe ApiController do
  let(:dialog1)    { FactoryGirl.create(:dialog, :label => "ServiceDialog1") }
  let(:dialog2)    { FactoryGirl.create(:dialog, :label => "ServiceDialog2") }

  let(:ra1)        { FactoryGirl.create(:resource_action, :action => "Provision", :dialog => dialog1) }
  let(:ra2)        { FactoryGirl.create(:resource_action, :action => "Retirement", :dialog => dialog2) }

  let(:picture)    { FactoryGirl.create(:picture, :extension => "jpg") }
  let(:template)   { FactoryGirl.create(:service_template, :name => "ServiceTemplate") }

  describe "Service Templates query" do
    before do
      template.resource_actions = [ra1, ra2]
      template.picture = picture
      api_basic_authorize
    end

    it "queries all resource actions of a Service Template" do
      run_get "#{service_templates_url(template.id)}/resource_actions", :expand => "resources"

      resource_actions = template.resource_actions
      expect_query_result(:resource_actions, resource_actions.count, resource_actions.count)
      expect_result_resources_to_include_data("resources", "action" => resource_actions.pluck(:action))
    end

    it "queries a specific resource action of a Service Template" do
      run_get "#{service_templates_url(template.id)}/resource_actions",
              :expand => "resources",
              :filter => ["action='Provision'"]

      expect_query_result(:resource_actions, 1, 2)
      expect_result_resources_to_match_hash(["id" => ra1.id, "action" => ra1.action, "dialog_id" => dialog1.id])
    end

    it "allows queries of the related picture" do
      run_get service_templates_url(template.id), :attributes => "picture"

      expect_result_to_have_keys(%w(id href picture))
      expect_result_to_match_hash(@result, "id" => template.id, "href" => service_templates_url(template.id))
    end

    it "allows queries of the related picture and image_href" do
      run_get service_templates_url(template.id), :attributes => "picture,picture.image_href"

      expect_result_to_have_keys(%w(id href picture))
      expect_result_to_match_hash(@result["picture"],
                                  "id"          => picture.id,
                                  "resource_id" => template.id,
                                  "image_href"  => /^http:.*#{picture.image_href}$/)
    end
  end

  describe "Service Templates edit" do
    it "rejects requests without appropriate role" do
      api_basic_authorize

      st = FactoryGirl.create(:service_template, :name => "st")
      run_post(service_templates_url(st.id), gen_request(:edit, "name" => "sample service template"))

      expect_request_forbidden
    end

    it "supports edits of single resource" do
      api_basic_authorize collection_action_identifier(:service_templates, :edit)

      st = FactoryGirl.create(:service_template, :name => "st1")
      run_post(service_templates_url(st.id), gen_request(:edit, "name" => "updated st1"))

      expect_single_resource_query("id" => st.id, "href" => service_templates_url(st.id), "name" => "updated st1")
      expect(st.reload.name).to eq("updated st1")
    end

    it "supports edits of multiple resources" do
      api_basic_authorize collection_action_identifier(:service_templates, :edit)

      st1 = FactoryGirl.create(:service_template, :name => "st1")
      st2 = FactoryGirl.create(:service_template, :name => "st2")

      run_post(service_templates_url, gen_request(:edit,
                                                  [{"href" => service_templates_url(st1.id), "name" => "updated st1"},
                                                   {"href" => service_templates_url(st2.id), "name" => "updated st2"}]))

      expect_request_success
      expect_results_to_match_hash("results",
                                   [{"id" => st1.id, "name" => "updated st1"},
                                    {"id" => st2.id, "name" => "updated st2"}])

      expect(st1.reload.name).to eq("updated st1")
      expect(st2.reload.name).to eq("updated st2")
    end
  end

  describe "Service Templates delete" do
    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(service_templates_url, gen_request(:delete, "href" => service_templates_url(100)))

      expect_request_forbidden
    end

    it "rejects resource deletion without appropriate role" do
      api_basic_authorize

      run_delete(service_templates_url(100))

      expect_request_forbidden
    end

    it "rejects resource deletes for invalid resources" do
      api_basic_authorize collection_action_identifier(:service_templates, :delete)

      run_delete(service_templates_url(999_999))

      expect_resource_not_found
    end

    it "supports single resource deletes" do
      api_basic_authorize collection_action_identifier(:service_templates, :delete)

      st = FactoryGirl.create(:service_template, :name => "st", :description => "st description")

      run_delete(service_templates_url(st.id))

      expect_request_success_with_no_content
      expect { st.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "supports multiple resource deletes" do
      api_basic_authorize collection_action_identifier(:service_templates, :delete)

      st1 = FactoryGirl.create(:service_template, :name => "st1", :description => "st1 description")
      st2 = FactoryGirl.create(:service_template, :name => "st2", :description => "st2 description")

      run_post(service_templates_url, gen_request(:delete,
                                                  [{"href" => service_templates_url(st1.id)},
                                                   {"href" => service_templates_url(st2.id)}]))
      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results",
                                               [service_templates_url(st1.id), service_templates_url(st2.id)])

      expect { st1.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { st2.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
