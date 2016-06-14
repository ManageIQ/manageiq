describe ReportController, "::Reports" do
  let(:user) { FactoryGirl.create(:user) }
  let(:chargeback_report) do
    FactoryGirl.create(:miq_report, :db => "ChargebackVm", :db_options => {:options => {:owner => user.userid}},
                                    :col_order => ["name"], :headers => ["Name"])
  end

  tabs = {:formatting => 2, :filter => 3, :summary => 4, :charts => 5, :timeline => 6, :preview => 7,
          :consolidation => 8, :styling => 9}

  chargeback_tabs = [:formatting, :filter, :preview]

  before { login_as user }

  describe "#build_edit_screen" do
    tabs.slice(*chargeback_tabs).each do |tab_number|
      it "flash messages should be nil" do
        controller.instance_variable_set(:@rpt, chargeback_report)
        controller.send(:set_form_vars)
        controller.instance_variable_set(:@sb, :miq_tab => "edit_#{tab_number.second}")
        controller.send(:build_edit_screen)

        expect(assigns(:flash_array)).to be_nil
      end
    end
  end

  describe "#check_tabs" do
    tabs.each_pair do |tab_title, tab_number|
      title = tab_title.to_s.titleize
      it "check existence of flash message when tab is changed to #{title} without selecting fields" do
        controller.instance_variable_set(:@sb, {})
        controller.instance_variable_set(:@edit, :new => {:fields => []})
        controller.instance_variable_set(:@_params, :tab => "new_#{tab_number}")
        controller.send(:check_tabs)
        flash_messages = assigns(:flash_array)
        flash_str = "#{title} tab is not available until at least 1 field has been selected"
        expect(flash_messages.first[:message]).to eq(flash_str)
        expect(flash_messages.first[:level]).to eq(:error)
      end

      it "flash messages should be nil when tab is changed to #{title} after selecting fields" do
        controller.instance_variable_set(:@sb, {})
        controller.instance_variable_set(:@edit, :new => {
                                           :fields  => [["Date Created", "Vm-ems_created_on"]],
                                           :sortby1 => "some_field"
                                         })
        controller.instance_variable_set(:@_params, :tab => "new_#{tab_number}")
        controller.send(:check_tabs)
        expect(assigns(:flash_array)).to be_nil
      end
    end

    it "check existence of flash message when tab is changed to preview without selecting filters(chargeback report)" do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@edit, :new => {:fields => [["Date Created"]], :model => "ChargebackVm"})
      controller.instance_variable_set(:@_params, :tab => "new_7") # preview
      controller.send(:check_tabs)
      flash_messages = assigns(:flash_array)
      expect(flash_messages).not_to be_nil
      flash_str = "Preview tab is not available until Chargeback Filters has been configured"
      expect(flash_messages.first[:message]).to eq(flash_str)
      expect(flash_messages.first[:level]).to eq(:error)
    end
  end

  describe "#miq_report_delete" do
    before do
      EvmSpecHelper.local_miq_server # timezone stuff
      login_as FactoryGirl.create(:user, :features => :miq_report_delete)
    end

    it "deletes the report" do
      FactoryGirl.create(:miq_report)
      report = FactoryGirl.create(:miq_report, :rpt_type => "Custom")
      session['sandboxes'] = {
        controller.controller_name => { :active_tree => 'report_1',
                      :trees => {'report_1' => {:active_node => "xx-0_xx-0-0_rep-#{report.id}"}}
        }
      }

      get :x_button, :params => { :id => report.id, :pressed => 'miq_report_delete' }
      expect(response.status).to eq(200)
      expect(MiqReport.find_by(:id => report.id)).to be_nil
    end

    it "cant delete default reports" do
      FactoryGirl.create(:miq_report)
      report = FactoryGirl.create(:miq_report, :rpt_type => "Default")
      session['sandboxes'] = {
        controller.controller_name => { :active_tree => 'report_1',
                      :trees => {'report_1' => {:active_node => "xx-0_xx-0-0_rep-#{report.id}"}}
        }
      }

      get :x_button, :params => { :id => report.id, :pressed => 'miq_report_delete' }
      expect(response.status).to eq(200)
      expect(MiqReport.find_by(:id => report.id)).not_to be_nil
    end

    # it "fails if widgets exist" do
    #   report = FactoryGirl.create(:miq_report)
    #   FactoryGirl.create(:miq_widget, :resource => report)
    # end
  end

  describe "#verify is_valid? flash messages" do
    it "show flash message when show cost by entity is selected but no entity_id chosen" do
      model = "ChargebackContainerProject"
      controller.instance_variable_set(:@edit, :new => {:model       => model,
                                                        :fields      => [["Date Created"]],
                                                        :cb_show_typ => "entity",
                                                        :cb_model    => "ContainerProject"})
      controller.instance_variable_set(:@sb, {})
      rpt = FactoryGirl.create(:miq_report_chargeback)
      controller.send(:valid_report?, rpt)
      flash_messages = assigns(:flash_array)
      flash_str = "A specific Project or all must be selected"
      expect(flash_messages.first[:message]).to eq(flash_str)
      expect(flash_messages.first[:level]).to eq(:error)
    end
  end
end
