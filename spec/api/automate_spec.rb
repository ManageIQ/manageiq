#
# REST API Request Tests - /api/automate
#
describe "Automate API" do
  context "Automate Queries" do
    before(:each) do
      MiqAeDatastore.reset
      FactoryGirl.create(:miq_ae_domain, :name => "ManageIQ", :tenant_id => @group.tenant.id)
      FactoryGirl.create(:miq_ae_domain, :name => "Custom",   :tenant_id => @group.tenant.id)
      system_class = FactoryGirl.create(:miq_ae_class, :name => "System", :namespace => "Custom")
      FactoryGirl.create(:miq_ae_field, :name    => "on_entry", :class_id => system_class.id,
                                        :aetype  => "state",    :datatype => "string")
    end

    it "returns domains by default" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get automate_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "name"      => "automate",
        "subcount"  => 2,
        "resources" => a_collection_containing_exactly(
          a_hash_including("name" => "Custom",   "fqname" => "/Custom"),
          a_hash_including("name" => "ManageIQ", "fqname" => "/ManageIQ")
        )
      )
    end

    it "default to depth 0 for non-root queries" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get automate_url("custom")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match(
        [a_hash_including("name" => "Custom", "fqname" => "/Custom")]
      )
    end

    it "supports depth 1" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get(automate_url("custom"), :depth => 1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array(
        [a_hash_including("name" => "Custom", "fqname" => "/Custom",        "domain_fqname" => "/"),
         a_hash_including("name" => "System", "fqname" => "/Custom/System", "domain_fqname" => "/System")]
      )
    end

    it "supports depth -1" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get(automate_url, :depth => -1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array(
        [a_hash_including("name" => "ManageIQ", "fqname" => "/ManageIQ"),
         a_hash_including("name" => "Custom",   "fqname" => "/Custom"),
         a_hash_including("name" => "System",   "fqname" => "/Custom/System")]
      )
    end

    it "supports state_machines search option" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get(automate_url, :depth => -1, :search_options => "state_machines")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array(
        [a_hash_including("name" => "Custom",   "fqname" => "/Custom"),
         a_hash_including("name" => "System",   "fqname" => "/Custom/System")]
      )
    end

    it "always return the fqname" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get(automate_url("custom/system"), :attributes => "name")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array([{"name" => "System", "fqname" => "/Custom/System"}])
    end
  end
end
