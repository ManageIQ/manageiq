require "spec_helper"
include UiConstants

describe ReportController do
  context "::Reports::Editor" do
    context "#set_form_vars" do
      it "check existence of cb_owner_id key" do
        user = FactoryGirl.create(:user)
        session[:userid] = user.userid
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
    end
  end
end
