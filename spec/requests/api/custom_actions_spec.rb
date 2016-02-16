#
# Rest API Request Tests - Custom Actions
#
# - Querying custom actions and custom action buttons of service templates
#       GET /api/service_templates/:id?attributes=custom_actions
#       GET /api/service_templates/:id?attributes=custom_action_buttons
#
# - Querying custom actions and custom action buttons of services
#       GET /api/services/:id?attributes=custom_actions
#       GET /api/services/:id?attributes=custom_action_buttons
#
# - Querying a service should also return in its actions the list
#   of custom actions.
#       GET /api/services/:id
#
# - Triggering a custom action on a service (case insensitive)
#       POST /api/services/:id
#          { "action" : "<custom_action_button_name>" }
#
describe ApiController do
  include_context "api request specs"

  let(:template1) { FactoryGirl.create(:service_template, :name => "template1") }
  let(:svc1) { FactoryGirl.create(:service, :name => "svc1", :service_template_id => template1.id) }

  let(:button1) do
    FactoryGirl.create(:custom_button,
                       :name        => "button1",
                       :description => "button one",
                       :applies_to  => template1,
                       :userid      => api_config(:user))
  end

  let(:button2) do
    FactoryGirl.create(:custom_button,
                       :name        => "button2",
                       :description => "button two",
                       :applies_to  => template1,
                       :userid      => api_config(:user))
  end

  let(:button3) do
    FactoryGirl.create(:custom_button,
                       :name        => "button3",
                       :description => "button three",
                       :applies_to  => template1,
                       :userid      => api_config(:user))
  end

  let(:button_group1) do
    FactoryGirl.create(:custom_button_set,
                       :name        => "button_group1",
                       :description => "button group one",
                       :set_data    => {:applies_to_id => template1.id, :applies_to_class => template1.class.name},
                       :owner       => template1)
  end

  def create_custom_buttons
    button1
    button_group1.replace_children([button2, button3])
  end

  def expect_result_to_have_custom_actions_hash
    expect_result_to_have_keys(%w(custom_actions))
    custom_actions = @result["custom_actions"]
    expect_hash_to_have_only_keys(custom_actions, %w(buttons button_groups))
    expect(custom_actions["buttons"].size).to eq(1)
    expect(custom_actions["button_groups"].size).to eq(1)
    expect(custom_actions["button_groups"].first["buttons"].size).to eq(2)
  end

  describe "Querying services with no custom actions" do
    it "returns core actions as authorized" do
      api_basic_authorize action_identifier(:services, :edit)

      run_get services_url(svc1.id)

      expect_result_to_have_keys(%w(id href actions))
      expect(@result["actions"].collect { |a| a["name"] }).to match_array(%w(edit))
    end
  end

  describe "Querying services with custom actions" do
    before(:each) do
      create_custom_buttons
    end

    it "returns core actions as authorized including custom action buttons" do
      api_basic_authorize action_identifier(:services, :edit)

      run_get services_url(svc1.id)

      expect_result_to_have_keys(%w(id href actions))
      expect(@result["actions"].collect { |a| a["name"] }).to match_array(%w(edit button1 button2 button3))
    end

    it "supports the custom_actions attribute" do
      api_basic_authorize action_identifier(:services, :edit)

      run_get services_url(svc1.id), :attributes => "custom_actions"

      expect_result_to_have_keys(%w(id href))
      expect_result_to_have_custom_actions_hash
    end

    it "supports the custom_action_buttons attribute" do
      api_basic_authorize action_identifier(:services, :edit)

      run_get services_url(svc1.id), :attributes => "custom_action_buttons"

      expect_result_to_have_keys(%w(id href custom_action_buttons))
      expect(@result["custom_action_buttons"].size).to eq(3)
    end
  end

  describe "Querying service_templates with custom actions" do
    before(:each) do
      create_custom_buttons
    end

    it "returns core actions as authorized excluding custom action buttons" do
      api_basic_authorize action_identifier(:service_templates, :edit)

      run_get service_templates_url(template1.id)

      expect_result_to_have_keys(%w(id href actions))
      action_specs = @result["actions"]
      expect(action_specs.size).to eq(1)
      expect(action_specs.first["name"]).to eq("edit")
    end

    it "supports the custom_actions attribute" do
      api_basic_authorize

      run_get service_templates_url(template1.id), :attributes => "custom_actions"

      expect_result_to_have_keys(%w(id href))
      expect_result_to_have_custom_actions_hash
    end

    it "supports the custom_action_buttons attribute" do
      api_basic_authorize

      run_get service_templates_url(template1.id), :attributes => "custom_action_buttons"

      expect_result_to_have_keys(%w(id href custom_action_buttons))
      expect(@result["custom_action_buttons"].size).to eq(3)
    end
  end

  describe "Services with custom actions" do
    before(:each) do
      create_custom_buttons
      button1.resource_action = FactoryGirl.create(:resource_action)
    end

    it "accepts a custom action" do
      api_basic_authorize

      run_post(services_url(svc1.id), gen_request(:button1, "button_key1" => "value", "button_key2" => "value"))

      expect_single_action_result(:success => true, :message => /.*/, :href => services_url(svc1.id))
    end

    it "accepts a custom action as case insensitive" do
      api_basic_authorize

      run_post(services_url(svc1.id), gen_request(:BuTtOn1, "button_key1" => "value", "button_key2" => "value"))

      expect_single_action_result(:success => true, :message => /.*/, :href => services_url(svc1.id))
    end
  end

  describe "Services with custom button dialogs" do
    it "queries for custom_actions returns expanded details for dialog buttons" do
      api_basic_authorize

      template2 = FactoryGirl.create(:service_template, :name => "template2")
      dialog2   = FactoryGirl.create(:dialog, :label => "dialog2")
      ra2       = FactoryGirl.create(:resource_action, :dialog_id => dialog2.id)
      button2   = FactoryGirl.create(:custom_button, :applies_to => template2, :userid => api_config(:user))
      svc2      = FactoryGirl.create(:service, :name => "svc2", :service_template_id => template2.id)
      button2.resource_action = ra2

      run_get services_url(svc2.id), :attributes => "custom_actions"

      expect_result_to_have_keys(%w(custom_actions))
      custom_actions = @result["custom_actions"]
      expect_hash_to_have_only_keys(custom_actions, %w(buttons button_groups))
      expect(custom_actions["buttons"].size).to eq(1)
      button = @result["custom_actions"]["buttons"].first
      expect_hash_to_have_keys(button, %w(id resource_action))
      ra = button["resource_action"]
      expect_hash_to_have_keys(ra, %w(id dialog_id dialog))
      expect_result_to_match_hash(ra, "id" => ra2.id, "dialog_id" => ra2.dialog_id)
      expect(ra["dialog"]["label"]).to eq(dialog2.label)
    end
  end
end
