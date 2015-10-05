require "spec_helper"

describe ReportController do
  context "::Dashboards" do
    context "#db_edit" do
      let(:user) { FactoryGirl.create(:user, :features => "db_edit") }
      before :each do
        login_as user
        @db = FactoryGirl.create(:miq_widget_set,
                                 :owner    => user.current_group,
                                 :set_data => {:col1 => [], :col2 => [], :col3 => []})
      end

      it "dashboard owner remains unchanged" do
        controller.stub(:db_fields_validation)
        controller.stub(:replace_right_cell)
        owner = @db.owner
        new_hash = {:name => "New Name", :description => "New Description", :col1 => [1], :col2 => [], :col3 => []}
        current = {:name => "New Name", :description => "New Description", :col1 => [], :col2 => [], :col3 => []}
        controller.instance_variable_set(:@edit, :new => new_hash, :db_id => @db.id, :current => current)
        controller.instance_variable_set(:@_params, {:id => @db.id, :button => "save"})
        controller.db_edit
        @db.owner.id.should == owner.id
        assigns(:flash_array).first[:message].should include("saved")
        controller.send(:flash_errors?).should_not be_true
      end
    end
  end
end
