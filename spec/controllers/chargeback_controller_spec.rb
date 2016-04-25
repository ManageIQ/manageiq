describe ChargebackController do
  before { set_user_privileges }

  context "returns current rate assignments or set them to blank if category/tag is deleted" do
    let(:category) { FactoryGirl.create(:classification) }
    let(:tag)      { FactoryGirl.create(:classification, :parent_id => category.id) }
    let(:entry)    { FactoryGirl.create(:classification, :parent_id => tag.id) }

    context "#get_tags_all" do
      before { entry }

      it "returns the classification entry record" do
        controller.instance_variable_set(:@edit, :cb_assign => {:tags => {}})
        controller.send(:get_tags_all, tag.id)
        expect(assigns(:edit)[:cb_assign][:tags]).to eq(entry.id.to_s => entry.description)
      end

      it "returns empty hash when classification entry is not found" do
        controller.instance_variable_set(:@edit, :cb_assign => {:tags => {}})
        controller.send(:get_tags_all, 1)
        expect(assigns(:edit)[:cb_assign][:tags]).to eq({})
      end
    end

    context "#cb_assign_set_form_vars" do
      before do
        cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Storage")
        ChargebackRate.set_assignments(:Storage, [{:cb_rate => cbr, :tag => [tag, "vm"]}])
        sandbox = {:active_tree => :cb_assignments_tree, :trees => {:cb_assignments_tree => {:active_node => 'xx-Storage'}}}
        controller.instance_variable_set(:@sb, sandbox)
      end

      it "returns tag for current assignments" do
        controller.send(:cb_assign_set_form_vars)
        expect(assigns(:edit)[:current_assignment][0][:tag][0]['parent_id']).to eq(category.id)
      end

      it "returns empty array for current_assignment when tag/category is not found" do
        tag.destroy
        controller.send(:cb_assign_set_form_vars)
        expect(assigns(:edit)[:current_assignment]).to eq([])
      end
    end
  end

  context "Saved chargeback rendering" do
    it "Saved chargeback reports renders paginagion buttons correctly" do
      report = FactoryGirl.create(:miq_report_with_results)
      report.extras = {:total_html_rows => 100}
      rp_id = report.id
      rr_id = report.miq_report_results[0].id
      node = "xx-#{rp_id}-2_rr-#{rr_id}"
      html = '<table><thead><tr><th>column 1</th><th>column 2</th></thead><tbody>'
      100.times do
        html += '<tr><td>col1 value</td><td>col2 value</td></tr>'
      end
      html += '</tbody></table>'

      allow(controller).to  receive(:cb_rpts_show_saved_report)
      expect(controller).to receive(:render)
      controller.instance_variable_set(:@sb,
                                       :active_tree => :cb_reports_tree,
                                       :trees       => {:cb_reports_tree => {:active_node => node}})
      controller.instance_variable_set(:@report, report)
      controller.instance_variable_set(:@html, html)
      controller.instance_variable_set(:@layout, "chargeback")
      controller.instance_variable_set(:@_params, :id => node)
      controller.send(:tree_select)
      expect(response).to                        render_template('layouts/_saved_report_paging_bar')
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(response.status).to                 eq(200)
    end
  end

  context "#explorer" do
    render_views

    it "can be rendered" do
      EvmSpecHelper.create_guid_miq_server_zone
      get :explorer
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end
  end

  context "#process_cb_rates" do
    it "delete unassigned" do
      cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Storage", :description => "Storage Rate")

      rates = [cbr.id]
      controller.send(:process_cb_rates, rates, "destroy")

      expect(controller.send(:flash_errors?)).to be_falsey

      flash_array = assigns(:flash_array)
      expect(flash_array.first[:message]).to include("Delete successful")
    end

    it "delete assigned" do
      cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Storage", :description => "Storage Rate")
      host = FactoryGirl.create(:host)
      cbr.assign_to_objects(host)

      rates = [cbr.id]
      controller.send(:process_cb_rates, rates, "destroy")

      expect(controller.send(:flash_errors?)).to be_truthy

      flash_array = assigns(:flash_array)
      expect(flash_array.first[:message]).to include("rate is assigned and cannot be deleted")
    end
  end

  context "#get_cis_all" do
    let!(:storage) { FactoryGirl.create(:storage) }
    let!(:miq_enterprise) { FactoryGirl.create(:miq_enterprise) }

    it "returns names of instances of enterprise" do
      names_miqent = {}
      MiqEnterprise.all.each do |instance|
        names_miqent[instance.id] = instance.name
      end
      controller.instance_variable_set(:@edit, :new => {:cbshow_typ => "enterprise"}, :cb_assign => {})
      controller.send(:get_cis_all)
      expect(assigns(:edit)[:cb_assign][:cis]).to eq(names_miqent)
    end

    it "returns names of instances of storage" do
      names_storage = {}
      element = "storage"
      element.classify.constantize.all.each do |instance|
        names_storage[instance.id] = instance.name
      end
      controller.instance_variable_set(:@edit, :new => {:cbshow_typ => element}, :cb_assign => {})
      controller.send(:get_cis_all)
      expect(assigns(:edit)[:cb_assign][:cis]).to eq(names_storage)
    end

    it "returns a ArgumentError when element not in whitelist" do
      controller.instance_variable_set(:@edit, :new => {:cbshow_typ => "None"}, :cb_assign => {})
      expect { controller.send(:get_cis_all) }.to raise_error(ArgumentError)
    end

    it "doesn't names of instances when nothing is selected" do
      controller.instance_variable_set(:@edit,
                                       :new => {:cbshow_typ => described_class::NOTHING_FORM_VALUE}, :cb_assign => {})
      controller.send(:get_cis_all)
      expect(assigns(:edit)[:cb_assign][:cis]).to eq({})
    end
  end

  context "chargeback rate form actions" do
    # indexing inputs regard to database
    # html inputs have names(and ids) in form "start_0_0", "finish_0_2"
    # it means "start_[num_of_rate_detail]_[num_of_tier]"

    # for example we have in database:
    # chargeback_rate => [
    #                     chargeback_rate_details_0 => [
    #                                                 chargeback_tiers_0  => index of tier : 0_0
    #                                                 chargeback_tiers_1  => index of tier : 0_1
    #                                                 chargeback_tiers_2  => index of tier : 0_2
    #                                                ]
    #                     chargeback_rate_details_1 => [
    #                                                 chargeback_tiers_0  => index of tier : 1_0
    #                                                 chargeback_tiers_1  => index of tier : 1_1
    #                                                 chargeback_tiers_2  => index of tier : 1_2
    #                                                ]
    # ]
    #

    render_views

    let(:chargeback_rate) { FactoryGirl.create(:chargeback_rate_with_details) }

    # this index represent first rate detail( "Allocated Memory in MB") chargeback_rate
    let(:index_to_rate_type) { "0" }

    before do
      EvmSpecHelper.local_miq_server
      allow_any_instance_of(described_class).to receive(:center_toolbar_filename).and_return("chargeback_center_tb")
      seed_session_trees('chargeback', :cb_rates_tree, "xx-Compute_cr-#{controller.to_cid(chargeback_rate.id)}")
    end

    def expect_input(body, selector, value)
      expect(body).to have_selector("input[value='#{value}']##{selector}")
    end

    def expect_rendered_tiers(body, tiers, order_of_rate_detail = 0)
      tiers.each_with_index do |tier, index|
        expect_input(body, "start_#{order_of_rate_detail}_#{index}", tier[:start])
        finish_tier_value = tier[:finish] == Float::INFINITY ? "" : tier[:finish]
        expect_input(body, "finish_#{order_of_rate_detail}_#{index}", finish_tier_value)
      end
    end

    def change_form_value(field, value)
      post :cb_rate_form_field_changed, :params => {:id => chargeback_rate.id, field => value}
    end

    it "renders edit form with correct values" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}
      response_body = response.body.delete('\\')
      expect(response).to render_template(:partial => 'chargeback/_cb_rate_edit')
      expect(response).to render_template(:partial => 'chargeback/_cb_rate_edit_table')

      expect_input(response_body, "description", "foo")

      expect_rendered_tiers(response_body, [{:start => "0.0", :finish => "20.0"},
                                            {:start => "20.0", :finish => "40.0"},
                                            {:start => "40.0", :finish => Float::INFINITY}])

      expect_rendered_tiers(response_body, [{:start => "0.0", :finish => Float::INFINITY}], 1)
    end

    it "removes requested tier line from edit from" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}
      post :cb_tier_remove, :params => {:button => "remove", :index => "0-1"}

      response_body = response.body.delete('\\').gsub('u003e', ">").gsub('u003c', "<")

      expect(response).to render_template(:partial => 'chargeback/_cb_rate_edit_table')

      expect_rendered_tiers(response_body, [{:start => "0.0", :finish => "20.0"},
                                            {:start => "40.0", :finish => Float::INFINITY}])

      expect_rendered_tiers(response_body, [{:start => "0.0", :finish => Float::INFINITY}], 1)
    end

    it "removes requested tier line and add 2 new tiers line from edit from" do
      count_of_tiers = chargeback_rate.chargeback_rate_details[index_to_rate_type.to_i].chargeback_tiers.count
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}
      post :cb_tier_remove, :params => {:button => "remove", :index => "#{index_to_rate_type}-1"}
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}

      response_body = response.body.delete('\\').gsub('u003e', ">").gsub('u003c', "<")

      count_of_last_tier = count_of_tiers - 1 + 2 # one tier removed, two tiers added
      selector = "#{index_to_rate_type}_#{count_of_last_tier - 1}"
      expect_input(response_body, "start_#{selector}", "")
      expect_input(response_body, "finish_#{selector}", "")
    end

    it "saves edited chargeback rate" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}

      # remove second tier for rate detail; (values  {:start => "20.0", :finish => "40.0"})
      post :cb_tier_remove, :params => {:button => "remove", :index => "#{index_to_rate_type}-1"}

      # add new tier, new position is index_to_rate_type-1
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}

      # add new tier at, new position is index_to_rate_type-2
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}

      # after these actions we have for rate detail values:
      # 0-0 :start => 0.0, :finish => 20.0
      # 0-1 :start => 40.0, :finish => Infinity
      # 0-2 :start => Infinity, :finish => Infinity
      # 0-3 :start => Infinity, :finish => Infinity

      # add values to newly added tiers to be valid
      change_form_value(:start_0_1, "20.0")
      change_form_value(:finish_0_1, "50.0")
      change_form_value(:start_0_2, "50.0")
      change_form_value(:finish_0_2, "70.0")
      change_form_value(:start_0_3, "70.0")

      # so after updating form values we have tiers with valid values
      # 0-0 :start => 0.0, :finish => 30.0
      # 0-1 :start => 30.0, :finish => 50.0
      # 0-2 :start => 50.0, :finish => 70.0
      # 0-3 :start => 70.0, :finish => Infinity

      post :cb_rate_edit, :params => {:button => "save", :id => chargeback_rate.id}

      rate_detail = ChargebackRate.find(chargeback_rate.id).chargeback_rate_details[index_to_rate_type.to_i]
      expect(rate_detail.chargeback_tiers[0]).to have_attributes(:start => 0.0, :finish => 20.0)
      expect(rate_detail.chargeback_tiers[1]).to have_attributes(:start => 20.0, :finish => 50.0)
      expect(rate_detail.chargeback_tiers[2]).to have_attributes(:start => 50.0, :finish => 70.0)
      expect(rate_detail.chargeback_tiers[3]).to have_attributes(:start => 70.0, :finish => Float::INFINITY)
    end
  end
end
