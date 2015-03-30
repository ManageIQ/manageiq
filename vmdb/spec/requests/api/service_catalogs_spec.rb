#
# Rest API Request Tests - Service Catalogs specs
#
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
require 'spec_helper'

describe ApiController do
  include Rack::Test::Methods

  before(:each) do
    init_api_spec_env
  end

  def sc_templates_url(id)
    "#{service_catalogs_url(id)}/service_templates"
  end

  def app
    Vmdb::Application
  end

  describe "Service Catalogs create" do
    it "rejects resource creation without appropriate role" do
      api_basic_authorize

      run_post(service_catalogs_url, gen_request(:add, "name" => "sample service catalog"))

      expect_request_forbidden
    end

    it "rejects resource creation with id specified" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :add)

      run_post(service_catalogs_url, gen_request(:add, "name" => "sample service catalog", "id" => 100))

      expect_bad_request(/id or href should not be specified/i)
    end

    it "supports single resource creation" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :add)

      run_post(service_catalogs_url, gen_request(:add, "name" => "sample service catalog"))

      expect_request_success
      expect_result_resource_keys_to_be_like_klass("results", "id", Integer)
      expect_results_to_match_hash("results", [{"name" => "sample service catalog"}])

      sc_id = @result["results"].first["id"]

      expect(ServiceTemplateCatalog.find(sc_id)).to be_true
    end

    it "supports multiple resource creation" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :add)

      run_post(service_catalogs_url, gen_request(:add, [{"name" => "sc1"}, {"name" => "sc2"}]))

      expect_request_success
      expect_result_resource_keys_to_be_like_klass("results", "id", Integer)
      expect_results_to_match_hash("results", [{"name" => "sc1"}, {"name" => "sc2"}])

      results = @result["results"]
      sc_id1, sc_id2 = results.first["id"], results.second["id"]
      expect(ServiceTemplateCatalog.find(sc_id1)).to be_true
      expect(ServiceTemplateCatalog.find(sc_id2)).to be_true
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

      expect_request_success
      expect_results_to_match_hash("results", [{"name" => "sc", "description" => "sc description"}])

      sc_id = @result["results"].first["id"]

      expect(ServiceTemplateCatalog.find(sc_id)).to be_true
      expect(ServiceTemplateCatalog.find(sc_id).service_templates.pluck(:id)).to match_array([st1.id, st2.id])
    end
  end

  describe "Service Catalogs edit" do
    it "rejects resource edits without appropriate role" do
      api_basic_authorize

      run_post(service_catalogs_url, gen_request(:edit, "name" => "sc1", "href" => service_catalogs_url(999_999)))

      expect_request_forbidden
    end

    it "rejects edits for invalid resources" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :edit)

      run_post(service_catalogs_url(999_999), gen_request(:edit, "description" => "updated sc description"))

      expect_resource_not_found
    end

    it "supports single resource edit" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :edit)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")

      run_post(service_catalogs_url(sc.id), gen_request(:edit, "description" => "updated sc description"))

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

      expect_request_forbidden
    end

    it "rejects resource deletion without appropriate role" do
      api_basic_authorize

      run_delete(service_catalogs_url(100))

      expect_request_forbidden
    end

    it "rejects resource deletes for invalid resources" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :delete)

      run_delete(service_catalogs_url(999_999))

      expect_resource_not_found
    end

    it "supports single resource deletes" do
      api_basic_authorize collection_action_identifier(:service_catalogs, :delete)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")

      run_delete(service_catalogs_url(sc.id))

      expect_request_success_with_no_content
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

      expect_request_forbidden
    end

    it "rejects unassign requests without appropriate role" do
      api_basic_authorize

      run_post(sc_templates_url(100), gen_request(:unassign, "href" => service_templates_url(1)))

      expect_request_forbidden
    end

    it "rejects assign requests with invalid service template" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :assign)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")

      run_post(sc_templates_url(sc.id), gen_request(:assign, "href" => service_templates_url(999_999)))

      expect_resource_not_found
    end

    it "supports assign requests" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :assign)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")
      st = FactoryGirl.create(:service_template)

      run_post(sc_templates_url(sc.id), gen_request(:assign, "href" => service_templates_url(st.id)))

      expect_request_success
      expect(sc.reload.service_templates.pluck(:id)).to eq([st.id])
    end

    it "supports unassign requests" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :assign)

      sc = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")
      st1 = FactoryGirl.create(:service_template)
      st2 = FactoryGirl.create(:service_template)
      sc.service_templates = [st1, st2]

      run_post(sc_templates_url(sc.id), gen_request(:unassign, "href" => service_templates_url(st1.id)))

      expect_request_success
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

    it "rejects order requests without appropriate role" do
      api_basic_authorize

      run_post(sc_templates_url(100), gen_request(:order, "href" => service_templates_url(1)))

      expect_request_forbidden
    end

    it "supports single order request" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :order)

      sc  = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")
      st1 = FactoryGirl.create(:service_template, :name => "service template 1")
      sc.service_templates = [st1]

      run_post("#{sc_templates_url(sc.id)}/#{st1.id}", gen_request(:order))

      expect_single_resource_query(order_request)
    end

    it "supports multiple order requests" do
      api_basic_authorize subcollection_action_identifier(:service_catalogs, :service_templates, :order)

      sc  = FactoryGirl.create(:service_template_catalog, :name => "sc", :description => "sc description")
      st1 = FactoryGirl.create(:service_template, :name => "service template 1")
      st2 = FactoryGirl.create(:service_template, :name => "service template 1")
      sc.service_templates = [st1, st2]

      run_post(sc_templates_url(sc.id), gen_request(:order, [{"href" => service_templates_url(st1.id)},
                                                             {"href" => service_templates_url(st2.id)}]))
      expect_request_success
      expect_results_to_match_hash("results", [order_request, order_request])
    end
  end
end
