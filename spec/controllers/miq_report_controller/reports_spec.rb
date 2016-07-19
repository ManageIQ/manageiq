describe ReportController, "::Reports" do
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
end
