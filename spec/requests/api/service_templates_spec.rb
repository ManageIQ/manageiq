#
# Rest API Request Tests - Service Templates specs
#
# - Edit service template               /api/service_templates/:id    action "edit"
# - Edit multiple service templates     /api/service_templates        action "edit"
# - Delete service template             /api/service_templates/:id    DELETE
# - Delete multiple service templates   /api/service_templates        action "delete"
#
require 'spec_helper'

describe ApiController do
  include Rack::Test::Methods

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
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
