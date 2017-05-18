RSpec.describe "Blueprints API" do
  describe "GET /api/blueprints" do
    it "lists all the blueprints with an appropriate role" do
      blueprint = FactoryGirl.create(:blueprint)
      api_basic_authorize collection_action_identifier(:blueprints, :read, :get)

      run_get(blueprints_url)

      expected = {
        "count"     => 1,
        "subcount"  => 1,
        "name"      => "blueprints",
        "resources" => [
          hash_including("href" => a_string_matching(blueprints_url(blueprint.id)))
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "forbids access to blueprints without an appropriate role" do
      FactoryGirl.create(:blueprint)
      api_basic_authorize

      run_get(blueprints_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/blueprints/:id" do
    it "will show a blueprint with an appropriate role" do
      blueprint = FactoryGirl.create(:blueprint)
      api_basic_authorize action_identifier(:blueprints, :read, :resource_actions, :get)

      run_get(blueprints_url(blueprint.id))

      expect(response.parsed_body).to include("href" => a_string_matching(blueprints_url(blueprint.id)))
      expect(response).to have_http_status(:ok)
    end

    it "forbids access to a blueprint without an appropriate role" do
      blueprint = FactoryGirl.create(:blueprint)
      api_basic_authorize

      run_get(blueprints_url(blueprint.id))

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/blueprints" do
    it "can create a blueprint" do
      api_basic_authorize collection_action_identifier(:blueprints, :create)
      ui_properties = {
        :service_catalog      => {},
        :service_dialog       => {},
        :automate_entrypoints => {},
        :chart_data_model     => {}
      }

      run_post(blueprints_url, :name => "foo", :description => "bar", :ui_properties => ui_properties)

      expected = {
        "results" => [
          a_hash_including(
            "name"          => "foo",
            "description"   => "bar",
            "ui_properties" => {
              "service_catalog"      => {},
              "service_dialog"       => {},
              "automate_entrypoints" => {},
              "chart_data_model"     => {}
            }
          )
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "rejects blueprint creation with id specified" do
      api_basic_authorize collection_action_identifier(:blueprints, :create)

      run_post(blueprints_url, :name => "foo", :description => "bar", :id => 123)

      expected = {
        "error" => a_hash_including(
          "kind"    => "bad_request",
          "message" => a_string_matching(/id or href should not be specified/i),
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects blueprint creation with an href specified" do
      api_basic_authorize collection_action_identifier(:blueprints, :create)

      run_post(blueprints_url, :name => "foo", :description => "bar", :href => blueprints_url(123))

      expected = {
        "error" => a_hash_including(
          "kind"    => "bad_request",
          "message" => a_string_matching(/id or href should not be specified/i),
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:bad_request)
    end

    it "can create blueprints in bulk" do
      api_basic_authorize collection_action_identifier(:blueprints, :create)
      ui_properties = {
        :service_catalog      => {},
        :service_dialog       => {},
        :automate_entrypoints => {},
        :chart_data_model     => {}
      }

      run_post(
        blueprints_url,
        :resources => [
          {:name => "foo", :description => "bar", :ui_properties => ui_properties},
          {:name => "baz", :description => "qux", :ui_properties => ui_properties}
        ]
      )

      expected = {
        "results" => a_collection_containing_exactly(
          a_hash_including("name" => "foo", "description" => "bar"),
          a_hash_including("name" => "baz", "description" => "qux")
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "forbids blueprint creation without an appropriate role" do
      api_basic_authorize

      run_post(blueprints_url, :name => "foo", :description => "bar", :ui_properties => {:some => {:json => "baz"}})

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/blueprints" do
    it "can update attributes of multiple blueprints with an appropirate role" do
      blueprint1 = FactoryGirl.create(:blueprint, :name => "foo")
      blueprint2 = FactoryGirl.create(:blueprint, :name => "bar")
      api_basic_authorize collection_action_identifier(:blueprints, :edit)

      run_post(blueprints_url, :action => "edit", :resources => [{:id => blueprint1.id, :name => "baz"},
                                                                 {:id => blueprint2.id, :name => "qux"}])

      expected = {
        "results" => a_collection_containing_exactly(
          a_hash_including(
            "id"   => blueprint1.id,
            "name" => "baz"
          ),
          a_hash_including(
            "id"   => blueprint2.id,
            "name" => "qux"
          )
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "forbids the updating of multiple blueprints without an appropriate role" do
      blueprint1 = FactoryGirl.create(:blueprint, :name => "foo")
      blueprint2 = FactoryGirl.create(:blueprint, :name => "bar")
      api_basic_authorize

      run_post(blueprints_url, :action => "edit", :resources => [{:id => blueprint1.id, :name => "baz"},
                                                                 {:id => blueprint2.id, :name => "qux"}])

      expect(response).to have_http_status(:forbidden)
    end

    it "can delete multiple blueprints" do
      blueprint1, blueprint2 = FactoryGirl.create_list(:blueprint, 2)
      api_basic_authorize collection_action_identifier(:blueprints, :delete)

      run_post(blueprints_url, :action => "delete", :resources => [{:id => blueprint1.id}, {:id => blueprint2.id}])

      expect(response).to have_http_status(:ok)
    end

    it "forbids multiple blueprint deletion without an appropriate role" do
      blueprint1, blueprint2 = FactoryGirl.create_list(:blueprint, 2)
      api_basic_authorize

      run_post(blueprints_url, :action => "delete", :resources => [{:id => blueprint1.id}, {:id => blueprint2.id}])

      expect(response).to have_http_status(:forbidden)
    end

    it "can publish multiple blueprints" do
      service_template = FactoryGirl.create(:service_template)
      dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
      ui_properties = {
        "service_dialog"        => {"id" => dialog.id},
        "chart_data_model"      => {
          "nodes" => [{
            "id"   => service_template.id,
            "tags" => []
          }]},
        "automate_entry_points" => {
          "Reconfigure" => "foo",
          "Provision"   => "bar"
        }
      }
      blueprint1, blueprint2 = FactoryGirl.create_list(:blueprint, 2, :ui_properties => ui_properties)

      api_basic_authorize collection_action_identifier(:blueprints, :publish)

      run_post(blueprints_url, :action => "publish", :resources => [{:id => blueprint1.id}, {:id => blueprint2.id}])

      expected = {
        "results" => a_collection_containing_exactly(
          a_hash_including("id" => blueprint1.id, "status" => "published"),
          a_hash_including("id" => blueprint2.id, "status" => "published")
        )
      }

      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/blueprints/:id" do
    it "forbids the updating of blueprints without an appropriate role" do
      blueprint = FactoryGirl.create(:blueprint, :name => "foo", :description => "bar")
      api_basic_authorize

      run_post(blueprints_url(blueprint.id), :action => "edit", :resource => {:name => "baz", :description => "qux"})

      expect(response).to have_http_status(:forbidden)
    end

    it "can delete a blueprint with an appropriate role" do
      blueprint = FactoryGirl.create(:blueprint)
      api_basic_authorize action_identifier(:blueprints, :delete)

      run_post(blueprints_url(blueprint.id), :action => "delete")

      expect(response).to have_http_status(:ok)
    end

    it "forbids blueprint deletion without an appropriate role" do
      blueprint = FactoryGirl.create(:blueprint)
      api_basic_authorize

      run_post(blueprints_url(blueprint.id), :action => "delete")

      expect(response).to have_http_status(:forbidden)
    end

    it "publishes a single blueprint" do
      service_template = FactoryGirl.create(:service_template)
      dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
      ui_properties = {
        "service_dialog"        => {"id" => dialog.id},
        "chart_data_model"      => {
          "nodes" => [{
            "id"   => service_template.id,
            "tags" => []
          }]},
        "automate_entry_points" => {
          "Reconfigure" => "foo",
          "Provision"   => "bar"
        }
      }
      blueprint = FactoryGirl.create(:blueprint, :ui_properties => ui_properties)
      api_basic_authorize action_identifier(:blueprints, :publish)

      run_post(blueprints_url(blueprint.id), :action => "publish")

      expected = {
        "id"     => blueprint.id,
        "status" => "published"
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "fails appropriately if a blueprint publish raises" do
      blueprint = FactoryGirl.create(:blueprint)
      api_basic_authorize action_identifier(:blueprints, :publish)

      run_post(blueprints_url(blueprint.id), :action => "publish")

      expected = {
        "error" => a_hash_including(
          "kind"    => "bad_request",
          "message" => a_string_matching(/Failed to publish blueprint - /i),
        )
      }

      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /api/blueprints/:id" do
    it "can delete a blueprint with an appropriate role" do
      blueprint = FactoryGirl.create(:blueprint)
      api_basic_authorize action_identifier(:blueprints, :delete, :resource_actions, :delete)

      run_delete(blueprints_url(blueprint.id))

      expect(response).to have_http_status(:no_content)
    end

    it "forbids blueprint deletion without an appropriate role" do
      blueprint = FactoryGirl.create(:blueprint)
      api_basic_authorize

      run_delete(blueprints_url(blueprint.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end
