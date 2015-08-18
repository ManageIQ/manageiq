require "spec_helper"
include UiConstants

describe ReportController do
  context "::Reports::Editor" do
    context "#set_form_vars" do
      it "check existence of cb_owner_id key" do
        user = FactoryGirl.create(:user)
        login_as user
        rep = FactoryGirl.create(
                                  :miq_report,
                                  :db => "Chargeback",
                                  :db_options => {:options => {:owner => user.userid}},
                                  :col_order => ["name"],
                                  :headers => ["Name"]
                                )
        controller.instance_variable_set(:@rpt, rep)
        controller.send(:set_form_vars)
        new_hash = assigns(:edit)[:new]
        new_hash.should have_key(:cb_owner_id)
        new_hash[:cb_owner_id].should == user.userid
      end

      it "should save the selected time zone with a chargeback report" do
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
        User.any_instance.stub(:role_allows?).and_return(true)

        controller.stub(:check_privileges).and_return(true)
        controller.stub(:load_edit).and_return(true)
        controller.stub(:valid_report?).and_return(true)
        controller.stub(:x_node).and_return("")
        controller.stub(:gfv_sort)
        controller.stub(:build_edit_screen)
        controller.stub(:get_all_widgets)
        controller.stub(:replace_right_cell)

        post :miq_report_edit, :id => rep.id, :button => 'save'

        rep.reload

        rep.tz.should == "Eastern Time (US & Canada)"
      end
    end
  end
end
