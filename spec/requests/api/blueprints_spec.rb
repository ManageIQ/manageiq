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

    it "will show a blueprint's bundle" do
      blueprint = FactoryGirl.create(:blueprint, :name => "Test Blueprint")
      service_templates = FactoryGirl.create_list(:service_template, 2)
      service_catalog   = FactoryGirl.create(:service_template_catalog)
      service_dialog    = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
      blueprint.create_bundle(:service_templates => service_templates,
                              :service_catalog   => service_catalog,
                              :service_dialog    => service_dialog)

      api_basic_authorize action_identifier(:blueprints, :read, :resource_actions, :get)

      run_get(blueprints_url(blueprint.id))

      expected = {
        "content" => a_hash_including(
          "id"                          => kind_of(Integer),
          "name"                        => blueprint.name,
          "service_type"                => "composite",
          "service_template_catalog_id" => service_catalog.id,
          "blueprint_id"                => blueprint.id
        )
      }
      expect(response.parsed_body).to include(expected)
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
      service_dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
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
      service_dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
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
  end

  describe "POST /api/blueprints/:id" do
    it "can update a blueprint's bundle with an appropriate role" do
      blueprint = FactoryGirl.create(:blueprint)

      original_service_template = FactoryGirl.create(:service_template)
      original_service_dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
      original_service_catalog = FactoryGirl.create(:service_template_catalog)
      blueprint.create_bundle(:service_templates => [original_service_template],
                              :service_dialog    => original_service_dialog,
                              :service_catalog   => original_service_catalog)
      new_service_template = FactoryGirl.create(:service_template)
      new_service_dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
      new_service_catalog = FactoryGirl.create(:service_template_catalog)

      api_basic_authorize action_identifier(:blueprints, :edit)

      run_post(
        blueprints_url(blueprint.id),
        :action   => "edit",
        :resource => {
          :bundle => {
            :service_templates    => [{:id => new_service_template.id}],
            :service_dialog       => {:id => new_service_dialog.id},
            :service_catalog      => {:id => new_service_catalog.id},
            :automate_entrypoints => {"Provision" => "a/b/c", "Reconfigure" => "x/y/z"}
          }
        }
      )

      expect(response).to have_http_status(:ok)
    end

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

    it "updates a blueprint to remove a service catalog" do
      blueprint = FactoryGirl.create(:blueprint)
      original_service_template = FactoryGirl.create(:service_template)
      original_service_catalog = FactoryGirl.create(:service_template_catalog)
      blueprint.create_bundle(:service_templates => [original_service_template],
                              :service_catalog   => original_service_catalog)
      api_basic_authorize action_identifier(:blueprints, :edit)

      run_post(
        blueprints_url(blueprint.id),
        :action   => "edit",
        :resource => {
          :bundle => {
            :service_catalog => {}
          }
        }
      )

      expect(blueprint.reload.bundle.descendants).to eq([])
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
