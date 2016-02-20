describe ReportController, "::Reports" do
  describe "#check_tabs" do
    tabs = {
      :formatting    => 2,
      :filter        => 3,
      :summary       => 4,
      :charts        => 5,
      :timeline      => 6,
      :preview       => 7,
      :consolidation => 8,
      :styling       => 9
    }
    tabs.each_pair do |tab_title, tab_number|
      title = tab_title.to_s.titleize
      it "check existence of flash message when tab is changed to #{title} without selecting fields" do
        login_as FactoryGirl.create(:user)
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
        login_as FactoryGirl.create(:user)
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
  end

  describe "#miq_report_delete" do
    before do
      EvmSpecHelper.local_miq_server # timezone stuff
      login_as FactoryGirl.create(:user, :features => :miq_report_delete)
      request.env['HTTP_REFERER'] = session['referer'] = controller.controller_name+"/" # work around referer security
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
end
