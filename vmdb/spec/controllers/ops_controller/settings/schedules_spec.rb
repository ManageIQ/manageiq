require "spec_helper"
require "debugger"

describe OpsController do
  let(:params) { {} }
  let(:session) { {} }

  before do
    #TODO: Change to shared context 'valid session' when merged
    set_user_privileges
  end

  describe "#schedule_form_fields" do
    pending
  end

  describe "#schedule_form_filter_type_field_changed" do
    before do
      params[:filter_type] = filter_type
      params[:id] = "123"
      session[:edit] = {:new => {:filter_type => filter_type}, :key => "schedule_edit__123"}
    end

    shared_examples_for "OpsController::Settings::Schedules#schedule_form_filter_type_field_changed" do
      it "assigns the filter type" do
        assigns(:edit)[:new][:filter_type].should == filter_type
      end
    end

    context "when the filter_type is 'vm'" do
      let(:vm) { Vm.new; instance_double("Vm", :name => "vmtest") }
      let(:filter_type) { "vm" }

      before do
        Vm.stub(:find).with(:all, {}).and_return([vm])
        post :schedule_form_filter_type_field_changed, params, session
      end

      it_behaves_like "OpsController::Settings::Schedules#schedule_form_filter_type_field_changed"

      it "responds with a filtered vm list" do
        json = JSON.parse(response.body)
        json["filtered_item_list"].should == ["vmtest"]
      end
    end

    context "when the filter_type is 'ems'" do
      let(:ext_management_system) { ExtManagementSystem.new; instance_double("ExtManagementSystem", :name => "emstest") }
      let(:filter_type) { "ems" }

      before do
        ExtManagementSystem.stub(:find).with(:all, {}).and_return([ext_management_system])
        post :schedule_form_filter_type_field_changed, params, session
      end

      it_behaves_like "OpsController::Settings::Schedules#schedule_form_filter_type_field_changed"

      it "responds with a filtered ext management system list" do
        json = JSON.parse(response.body)
        json["filtered_item_list"].should == ["emstest"]
      end
    end

    context "when the filter_type is 'cluster'" do
      let(:cluster) { EmsCluster.new; instance_double("EmsCluster", :name => "clustertest", :v_parent_datacenter => "datacenter", :v_qualified_desc => "desc") }
      let(:filter_type) { "cluster" }

      before do
        bypass_rescue
        EmsCluster.stub(:find).with(:all, {}).and_return([cluster])
        post :schedule_form_filter_type_field_changed, params, session
      end

      it_behaves_like "OpsController::Settings::Schedules#schedule_form_filter_type_field_changed"

      it "responds with a filtered cluster list" do
        json = JSON.parse(response.body)
        json["filtered_item_list"].should == [["clustertest__datacenter", "desc"]]
      end
    end

    context "when the filter_type is 'host'" do
      let(:host) { Host.new; instance_double("Host", :name => "hosttest") }
      let(:filter_type) { "host" }

      before do
        Host.stub(:find).with(:all, {}).and_return([host])
        post :schedule_form_filter_type_field_changed, params, session
      end

      it_behaves_like "OpsController::Settings::Schedules#schedule_form_filter_type_field_changed"

      it "responds with a filtered host list" do
        json = JSON.parse(response.body)
        json["filtered_item_list"].should == ["hosttest"]
      end
    end

    context "when the filter_type is 'global'" do
      let(:filter_type) { "global" }

      before do
        post :schedule_form_filter_type_field_changed, params, session
      end

      it "responds with a filtered global filter list" do
        pending
      end
    end

    context "when the filter_type is 'my'" do
      let(:filter_type) { "my" }

      before do
        post :schedule_form_filter_type_field_changed, params, session
      end

      it "responds with a filtered my_filter list" do
        pending
      end
    end
  end
end
