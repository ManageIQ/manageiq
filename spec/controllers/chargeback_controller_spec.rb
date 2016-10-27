describe ChargebackController do
  before { stub_user(:features => :all) }

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

    describe "#cb_rpt_build_folder_nodes" do
      let!(:admin_user)        { FactoryGirl.create(:user_admin) }
      let!(:chargeback_report) { FactoryGirl.create(:miq_report_chargeback_with_results) }

      before { login_as admin_user }

      it "returns list of saved chargeback report results" do
        controller.send(:cb_rpt_build_folder_nodes)

        parent_reports = controller.instance_variable_get(:@parent_reports)

        tree_id = "#{ApplicationRecord.compress_id(chargeback_report.id)}-0"
        expected_result = {chargeback_report.miq_report_results.first.miq_report.name => tree_id}
        expect(parent_reports).to eq(expected_result)
      end
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

    let(:chargeback_rate) { FactoryGirl.create(:chargeback_rate, :with_details, :description => "foo") }

    # this index represent first rate detail( "Allocated Memory in MB") chargeback_rate
    let(:index_to_rate_type) { "0" }

    before do
      EvmSpecHelper.local_miq_server
      allow_any_instance_of(described_class).to receive(:center_toolbar_filename).and_return("chargeback_center_tb")
      seed_session_trees('chargeback', :cb_rates_tree, "xx-Compute")
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

    def change_form_value(field, value, resource_action = nil)
      resource_action ||= chargeback_rate.id
      post :cb_rate_form_field_changed, :params => {:id => resource_action, field => value}
    end

    it "renders edit form with correct values" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}
      expect(response).to render_template(:partial => 'chargeback/_cb_rate_edit')
      expect(response).to render_template(:partial => 'chargeback/_cb_rate_edit_table')

      main_content = JSON.parse(response.body)['updatePartials']['main_div']
      expect_input(main_content, "description", "foo")

      expect_rendered_tiers(main_content, [{:start => "0.0", :finish => "20.0"},
                                            {:start => "20.0", :finish => "40.0"},
                                            {:start => "40.0", :finish => Float::INFINITY}])

      expect_rendered_tiers(main_content, [{:start => "0.0", :finish => Float::INFINITY}], 1)
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

    it "saves edited chargeback rate when 'per unit' is changed" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}

      change_form_value(:per_time_0, "monthly")

      post :cb_rate_edit, :params => {:button => "save", :id => chargeback_rate.id}

      rate_detail = ChargebackRate.find(chargeback_rate.id).chargeback_rate_details[index_to_rate_type.to_i]
      expect(rate_detail.per_time).to eq("monthly")
    end

    it "saves edited chargeback rate when 'per time' is changed" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}

      change_form_value(:per_unit_1, "teraherts")

      post :cb_rate_edit, :params => {:button => "save", :id => chargeback_rate.id}

      rate_detail = ChargebackRate.find(chargeback_rate.id).chargeback_rate_details[1]
      expect(rate_detail.per_unit).to eq("teraherts")
    end

    it "saves edited chargeback rate when value in finish column is changed to infinity (infinity is blank string)" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}
      # chargeback_rate[index_to_rate_type.to_i].chargeback_tiers contains
      # 0-0 :start => 0.0, :finish => 20.0
      # 0-1 :start => 20.0, :finish => 40.0  <- this value will be changed to Infinity
      # 0-2 :start => 40.0, :finish => Infinity  <- this will be removed

      post :cb_tier_remove, :params => {:button => "remove", :index => "#{index_to_rate_type}-2"}

      change_form_value(:finish_0_1, "") # infinity

      rate_detail = ChargebackRate.find(chargeback_rate.id).chargeback_rate_details[index_to_rate_type.to_i]

      post :cb_rate_edit, :params => {:button => "save", :id => chargeback_rate.id}

      expect(rate_detail.chargeback_tiers[1].finish).to eq(Float::INFINITY)
    end

    def expect_chargeback_rate_to_eq_hash(expected_rate, rate_hash)
      rate_hash[:rates].sort_by! { |rd| [rd[:group], rd[:description]] }

      expect(expected_rate.chargeback_rate_details.count).to eq(rate_hash[:rates].count)

      expected_rate.chargeback_rate_details.each_with_index do |rate_detail, index|
        rate_detail_hash = rate_hash[:rates][index]

        expect(rate_detail).to have_attributes(rate_detail_hash.slice(*ChargebackRateDetail::FORM_ATTRIBUTES))
        expect(rate_detail.detail_currency.name).to eq(rate_detail_hash[:type_currency])

        if rate_detail_hash[:measure].nil?
          expect(rate_detail.detail_measure).to be_nil
        else
          expect(rate_detail.detail_measure.name).to eq(rate_detail_hash[:measure])
        end

        rate_detail.chargeback_tiers.each_with_index do |tier, tier_index|
          tier_hash = rate_detail_hash[:tiers][tier_index]
          tier_hash[:finish] = ChargebackTier.to_float(tier_hash[:finish])
          expect(tier).to have_attributes(tier_hash)
        end
      end
    end

    let(:chargeback_rate_from_yaml) { File.join(ChargebackRate::FIXTURE_DIR, "chargeback_rates.yml") }
    let(:compute_chargeback_rate_hash_from_yaml) do
      rates_hash = YAML.load_file(chargeback_rate_from_yaml)
      rates_hash.select { |rate| rate[:rate_type] == "Compute" }.first
    end

    it "adds new chargeback rate using default values" do
      allow(controller).to receive(:load_edit).and_return(true)

      ChargebackRate.seed

      count_of_chargeback_rates = ChargebackRate.count

      post :x_button, :params => {:pressed => "chargeback_rates_new"}
      post :cb_rate_form_field_changed, :params => {:id => "new", :description => "chargeback rate 1"}
      post :cb_rate_edit, :params => {:button => "add"}

      expect(ChargebackRate.count).to eq(count_of_chargeback_rates + 1)

      new_chargeback_rate = ChargebackRate.last

      expect(File.exist?(chargeback_rate_from_yaml)).to be_truthy
      expect(new_chargeback_rate.description).to eq("chargeback rate 1")
      expect_chargeback_rate_to_eq_hash(new_chargeback_rate, compute_chargeback_rate_hash_from_yaml)
    end

    it "adds new chargeback rate and user adds and removes some tiers" do
      allow(controller).to receive(:load_edit).and_return(true)

      ChargebackRate.seed

      post :x_button, :params => {:pressed => "chargeback_rates_new"}
      post :cb_rate_form_field_changed, :params => {:id => "new", :description => "chargeback rate 1"}

      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}
      post :cb_tier_remove, :params => {:button => "remove", :index => "#{index_to_rate_type}-1"}
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}

      # add values to newly added tiers to be valid
      change_form_value(:finish_0_0, "20.0", "new")
      change_form_value(:start_0_1, "20.0", "new")
      change_form_value(:finish_0_1, "50.0", "new")
      change_form_value(:start_0_2, "50.0", "new")

      post :cb_rate_edit, :params => {:button => "add"}

      # change expected values from yaml
      compute_chargeback_rate_hash_from_yaml[:rates].sort_by! { |rd| [rd[:group], rd[:description]] }
      compute_rates = compute_chargeback_rate_hash_from_yaml[:rates][index_to_rate_type.to_i]
      compute_rates[:tiers][0][:finish] = 20.0
      compute_rates[:tiers].push(:start => 20.0, :finish => 50.0)
      compute_rates[:tiers].push(:start => 50.0, :finish => Float::INFINITY)

      new_chargeback_rate = ChargebackRate.last

      expect_chargeback_rate_to_eq_hash(new_chargeback_rate, compute_chargeback_rate_hash_from_yaml)
    end

    it "doesn't add new chargeback rate because some of tier has start value bigger than finish value" do
      allow(controller).to receive(:load_edit).and_return(true)

      ChargebackRate.seed

      post :x_button, :params => {:pressed => "chargeback_rates_new"}
      post :cb_rate_form_field_changed, :params => {:id => "new", :description => "chargeback rate 1"}

      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}
      post :cb_tier_remove, :params => {:button => "remove", :index => "#{index_to_rate_type}-1"}
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}

      # add values to newly added tiers to be valid
      change_form_value(:finish_0_0, "500.0", "new")
      change_form_value(:start_0_1, "500.0", "new")
      change_form_value(:finish_0_1, "50.0", "new")
      change_form_value(:start_0_2, "50.0", "new")

      post :cb_rate_edit, :params => {:button => "add"}

      flash_messages = assigns(:flash_array)

      expect(flash_messages.count).to eq(1)
      expected_message = "'Allocated CPU Count' finish value must be greater than start value."
      expect(flash_messages[0][:message]).to eq(expected_message)
    end

    def convert_chargeback_rate_to_hash(rate)
      origin_chargeback_rate_hash = {}
      origin_chargeback_rate_hash[:rates] = []
      rate.chargeback_rate_details.each do |rate_detail|
        rate_detail_hash = rate_detail.slice(*ChargebackRateDetail::FORM_ATTRIBUTES)
        rate_detail_hash = Hash[rate_detail_hash.map { |(k, v)| [k.to_sym, v] }]
        rate_detail_hash[:tiers] = []
        rate_detail.chargeback_tiers.each do |tier|
          tier_hash = tier.slice(*ChargebackTier::FORM_ATTRIBUTES)
          tier_hash = Hash[tier_hash.map { |(k, v)| [k.to_sym, v] }]
          rate_detail_hash[:tiers].push(tier_hash)
        end

        rate_detail_hash[:measure] = rate_detail.detail_measure.name
        rate_detail_hash[:type_currency] = rate_detail.detail_currency.name
        origin_chargeback_rate_hash[:rates].push(rate_detail_hash)
      end
      origin_chargeback_rate_hash
    end

    let(:origin_chargeback_rate_hash) { convert_chargeback_rate_to_hash(chargeback_rate) }

    it "copy existing chargeback rate" do
      post :x_button, :params => {:pressed => "chargeback_rates_copy", :id => chargeback_rate.id}

      post :cb_rate_edit, :params => {:button => "add"}

      new_charge_back_rate = ChargebackRate.last

      expect(new_charge_back_rate.description).to eq("copy of #{chargeback_rate.description}")
      expect_chargeback_rate_to_eq_hash(new_charge_back_rate, origin_chargeback_rate_hash)
    end

    it "copy existing chargeback rate and user adds and removes some tiers" do
      post :x_button, :params => {:pressed => "chargeback_rates_copy", :id => chargeback_rate.id}

      # remove and add some tier
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}
      post :cb_tier_remove, :params => {:button => "remove", :index => "#{index_to_rate_type}-1"}
      post :cb_tier_remove, :params => {:button => "remove", :index => "#{index_to_rate_type}-1"}
      post :cb_tier_add, :params => {:button => "add", :detail_index => index_to_rate_type}

      # back set values back to origin values
      change_form_value(:start_0_1, "20.0", "new")
      change_form_value(:finish_0_1, "40.0", "new")
      change_form_value(:fixed_rate_0_1, "0.3", "new")
      change_form_value(:variable_rate_0_1, "0.4", "new")

      change_form_value(:start_0_2, "40.0", "new")
      change_form_value(:finish_0_2, "", "new")
      change_form_value(:fixed_rate_0_2, "0.5", "new")
      change_form_value(:variable_rate_0_2, "0.6", "new")

      post :cb_rate_edit, :params => {:button => "add"}

      new_charge_back_rate = ChargebackRate.last

      expect(new_charge_back_rate.description).to eq("copy of #{chargeback_rate.description}")
      expect_chargeback_rate_to_eq_hash(new_charge_back_rate, origin_chargeback_rate_hash)
    end

    it "doesn't store rate and displays validation message with invalid input of tiers(uncontiguous tiers)" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}

      change_form_value(:start_0_1, "20.0")
      change_form_value(:finish_0_1, "40.0")
      change_form_value(:start_0_2, "60.0")
      change_form_value(:finish_0_2, "80.0")

      post :cb_rate_edit, :params => {:button => "save", :id => chargeback_rate.id}

      flash_messages = assigns(:flash_array)

      expect(flash_messages.count).to eq(1)
      expected_message = "'Allocated Memory in MB' chargeback tiers must start at zero and "
      expected_message += "not contain any gaps between start and prior end value."
      expect(flash_messages[0][:message]).to eq(expected_message)
    end

    it "doesn't store rate and displays validation message with invalid input of tiers(non-numberic tiers)" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}

      change_form_value(:start_0_1, "20.0typo")

      post :cb_rate_edit, :params => {:button => "save", :id => chargeback_rate.id}

      flash_messages = assigns(:flash_array)

      expect(flash_messages.count).to eq(1)
      expect(flash_messages[0][:message]).to eq("'Allocated Memory in MB' start is not a number")
    end

    it "doesn't store rate and displays validation message with invalid input of tiers(ambiguous tiers)" do
      post :x_button, :params => {:pressed => "chargeback_rates_edit", :id => chargeback_rate.id}

      change_form_value(:finish_0_1, "20.0")
      change_form_value(:start_0_1, "20.0")
      change_form_value(:finish_0_1, "20.0")
      change_form_value(:start_0_2, "20.0")

      post :cb_rate_edit, :params => {:button => "save", :id => chargeback_rate.id}

      flash_messages = assigns(:flash_array)

      expect(flash_messages.count).to eq(1)
      expected_message = "'Allocated Memory in MB' finish value must be greater than start value."
      expect(flash_messages[0][:message]).to eq(expected_message)
    end
  end

  describe "#cb_rpts_fetch_saved_report" do
    let(:current_user) { User.current_user }
    let(:miq_task)     { MiqTask.new(:name => "Generate Report result", :userid => current_user.userid) }
    let(:miq_report_result) do
      FactoryGirl.create(:miq_chargeback_report_result, :miq_group => current_user.current_group, :miq_task => miq_task)
    end

    let(:chargeback_report) { FactoryGirl.create(:miq_report_chargeback, :miq_report_results => [miq_report_result]) }

    before do
      miq_task.state_finished
      miq_report_result.report = chargeback_report.to_hash.merge(:extras=> {:total_html_rows => 100})
      miq_report_result.save
      allow(controller).to receive(:report_first_page)
    end

    it "fetch existing report" do
      controller.send(:cb_rpts_fetch_saved_report, controller.to_cid(miq_report_result.id))

      fetched_report = controller.instance_variable_get(:@report)

      expect(fetched_report).not_to be_nil
      expect(fetched_report).to eq(chargeback_report)
    end
  end
end
