describe "Actions API" do
  context "Actions CRUD" do
    let(:action) { FactoryGirl.create(:miq_action) }
    let(:actions) { FactoryGirl.create_list(:miq_action, 2) }
    let(:sample_action) do
      {
        :name        => "sample_action",
        :description => "sample_action",
        :action_type => "custom_automation",
        :options     => {:ae_message => "message", :ae_request => "request", :ae_hash => {"key"=>"value"}}
      }
    end
    let(:action_url) { actions_url(action.id) }

    it "forbids access to actions without an appropriate role" do
      action
      api_basic_authorize

      run_get(actions_url)

      expect(response).to have_http_status(:forbidden)
    end

    it "creates new action" do
      api_basic_authorize "action_new"
      run_post(actions_url, sample_action)

      expect(response).to have_http_status(:ok)

      action_id = response.parsed_body["results"].first["id"]

      expect(MiqAction.exists?(action_id)).to be_truthy
    end

    it "creates new actions" do
      api_basic_authorize "action_new"
      run_post(actions_url, gen_request(:create, [sample_action,
                                                  sample_action.merge(:name => "foo", :description => "bar")]))
      expect(response).to have_http_status(:ok)

      expect(response.parsed_body["results"].count).to eq(2)
    end

    it "reads all actions" do
      api_basic_authorize "action_show_list"
      FactoryGirl.create(:miq_action)
      run_get(actions_url)
      expect(response).to have_http_status(:ok)

      actions_amount = response.parsed_body["count"]

      expect(actions_amount).to eq(MiqAction.count)
    end

    it "deletes action" do
      api_basic_authorize "action_delete"
      run_post(actions_url, gen_request(:delete, "name" => action.name, "href" => action_url))

      expect(response).to have_http_status(:ok)

      expect(MiqAction.exists?(action.id)).to be_falsey
    end

    it "deletes actions" do
      api_basic_authorize "action_delete"
      run_post(actions_url, gen_request(:delete, [{"name" => actions.first.name,
                                                   "href" => actions_url(actions.first.id)},
                                                  {"name" => actions.second.name,
                                                   "href" => actions_url(actions.second.id)}]))

      expect(response).to have_http_status(:ok)

      expect(response.parsed_body["results"].count).to eq(2)
    end

    it "deletes action via DELETE" do
      api_basic_authorize "action_delete"

      run_delete(actions_url(action.id))

      expect(response).to have_http_status(:no_content)
      expect(MiqAction.exists?(action.id)).to be_falsey
    end

    it "edits new action" do
      api_basic_authorize "action_edit"
      run_post(action_url, gen_request(:edit, "description" => "change"))

      expect(response).to have_http_status(:ok)

      expect(MiqAction.find(action.id).description).to eq("change")
    end

    it "edits new actions" do
      api_basic_authorize "action_edit"
      run_post(actions_url, gen_request(:edit, [{"id" => actions.first.id, "description" => "change"},
                                                {"id" => actions.second.id, "description" => "change2"}]))
      expect(response).to have_http_status(:ok)

      expect(response.parsed_body["results"].count).to eq(2)

      expect(actions.first.reload.description).to eq("change")
      expect(actions.second.reload.description).to eq("change2")
    end
  end
end
