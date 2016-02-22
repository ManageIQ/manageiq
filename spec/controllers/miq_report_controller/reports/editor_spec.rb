describe ReportController do
  context "::Reports::Editor" do
    context "#set_form_vars" do
      it "check existence of cb_owner_id key" do
        user = FactoryGirl.create(:user)
        login_as user
        rep = FactoryGirl.create(
          :miq_report,
          :db         => "Chargeback",
          :db_options => {:options => {:owner => user.userid}},
          :col_order  => ["name"],
          :headers    => ["Name"]
        )
        controller.instance_variable_set(:@rpt, rep)
        controller.send(:set_form_vars)
        new_hash = assigns(:edit)[:new]
        expect(new_hash).to have_key(:cb_owner_id)
        expect(new_hash[:cb_owner_id]).to eq(user.userid)
      end

      it "should save the selected time zone with a chargeback report" do
        ApplicationController.handle_exceptions = true

        user = FactoryGirl.create(:user)
        login_as user
        rep = FactoryGirl.create(
          :miq_report,
          :db         => "Chargeback",
          :name       => 'name',
          :title      => 'title',
          :db_options => {:options => {:owner => user.userid}},
          :col_order  => ["name"],
          :headers    => ["Name"],
          :tz         => nil
        )

        edit = {
          :rpt_id  => rep.id,
          :new     => {
            :model  => "Chargeback",
            :name   => 'name',
            :title  => 'title',
            :tz     => "Eastern Time (US & Canada)",
            :fields => []
          },
          :current => {}
        }
        controller.instance_variable_set(:@edit, edit)
        session[:edit] = assigns(:edit)

        allow(User).to receive(:server_timezone).and_return("UTC")

        login_as user
        allow_any_instance_of(User).to receive(:role_allows?).and_return(true)

        allow(controller).to receive(:check_privileges).and_return(true)
        allow(controller).to receive(:load_edit).and_return(true)
        allow(controller).to receive(:valid_report?).and_return(true)
        allow(controller).to receive(:x_node).and_return("")
        allow(controller).to receive(:gfv_sort)
        allow(controller).to receive(:build_edit_screen)
        allow(controller).to receive(:get_all_widgets)
        allow(controller).to receive(:replace_right_cell)

        post :miq_report_edit, :params => { :id => rep.id, :button => 'save' }

        rep.reload

        expect(rep.tz).to eq("Eastern Time (US & Canada)")
      end
    end

    context "#miq_report_edit" do
      it "should build tabs with correct tab id after reset button is pressed to prevent error when changing tabs" do
        ApplicationController.handle_exceptions = true

        user = FactoryGirl.create(:user)
        login_as user
        rep = FactoryGirl.create(
          :miq_report,
          :rpt_type   => "Custom",
          :db         => "Host",
          :name       => 'name',
          :title      => 'title',
          :db_options => {},
          :col_order  => ["name"],
          :headers    => ["Name"],
          :tz         => nil
        )

        edit = {
          :rpt_id  => rep.id,
          :new     => {
            :model  => "Host",
            :name   => 'name',
            :title  => 'title',
            :tz     => "test",
            :fields => []
          },
          :current => {}
        }

        controller.instance_variable_set(:@edit, edit)
        session[:edit] = assigns(:edit)

        allow(User).to receive(:server_timezone).and_return("UTC")

        login_as user
        allow_any_instance_of(User).to receive(:role_allows?).and_return(true)

        allow(controller).to receive(:check_privileges).and_return(true)
        allow(controller).to receive(:load_edit).and_return(true)

        allow(controller).to receive(:replace_right_cell)

        post :miq_report_edit, :params => { :id => rep.id, :button => 'reset' }
        expect(assigns(:sb)[:miq_tab]).to eq("edit_1")
        expect(assigns(:tabs)).to include(["edit_1", ""])
      end
    end
  end
end
