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

      run_post(blueprints_url, :name => "foo", :description => "bar", :ui_properties => {:some => {:json => "baz"}})

      expected = {
        "results" => [
          a_hash_including(
            "name"          => "foo",
            "description"   => "bar",
            "ui_properties" => {"some" => {"json" => "baz"}}
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

    it "can create a blueprint with a bundle by href with an appropriate role" do
      service_dialog = build_dialog
      service_template_1, service_template_2 = FactoryGirl.create_list(:service_template, 2)
      service_catalog = FactoryGirl.create(:service_template_catalog)
      api_basic_authorize collection_action_identifier(:blueprints, :create)

      run_post(
        blueprints_url,
        :name        => "foo",
        :description => "bar",
        :bundle      => {
          :service_catalog      => {:href => service_catalogs_url(service_catalog.id)},
          :service_dialog       => {:href => service_dialogs_url(service_dialog.id)},
          :automate_entrypoints => {"Provision" => "a/b/c", "Reconfigure" => "x/y/z"},
          :service_templates    => [
            {:href => service_templates_url(service_template_1.id)},
            {:href => service_templates_url(service_template_2.id)}
          ]
        }
      )

      expect(response).to have_http_status(:ok)
    end

    it "can create a blueprint with a bundle by id with an appropriate role" do
      service_dialog = build_dialog
      service_template_1, service_template_2 = FactoryGirl.create_list(:service_template, 2)
      service_catalog = FactoryGirl.create(:service_template_catalog)
      api_basic_authorize collection_action_identifier(:blueprints, :create)

      run_post(
        blueprints_url,
        :name        => "foo",
        :description => "bar",
        :bundle      => {
          :service_catalog      => {:id => service_catalog.id},
          :service_dialog       => {:id => service_dialog.id},
          :automate_entrypoints => {"Provision" => "a/b/c", "Reconfigure" => "x/y/z"},
          :service_templates    => [
            {:id => service_template_1.id},
            {:id => service_template_2.id}
          ]
        }
      )

      expect(response).to have_http_status(:ok)
    end

    it "can create blueprints in bulk" do
      api_basic_authorize collection_action_identifier(:blueprints, :create)

      run_post(
        blueprints_url,
        :resources => [
          {:name => "foo", :description => "bar"},
          {:name => "baz", :description => "qux"}
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

  # TODO: factor this out of this test so it can be used elsewhere
  def build_dialog
    FactoryGirl.create(
      :dialog,
      :dialog_tabs => [
        FactoryGirl.create(
          :dialog_tab,
          :dialog_groups => [
            FactoryGirl.create(
              :dialog_group,
              :dialog_fields => [FactoryGirl.create(:dialog_field_text_box)]
            )
          ]
        )
      ]
    )
  end
end
