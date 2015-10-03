require "spec_helper"

describe OpsController do
  let(:params) { {} }
  let(:session) { {} }

  include_context "valid session"

  describe "#schedule_form_filter_type_field_changed" do
    before do
      params[:filter_type] = filter_type
      params[:id] = "123"
    end

    context "when the filter_type is 'vm'" do
      let(:vm) { active_record_instance_double("Vm", :name => "vmtest") }
      let(:filter_type) { "vm" }

      before do
        Vm.stub(:find).with(:all, {}).and_return([vm])
        post :schedule_form_filter_type_field_changed, params, session
      end

      it "responds with a filtered vm list" do
        json = JSON.parse(response.body)
        json["filtered_item_list"].should == ["vmtest"]
      end
    end

    context "when the filter_type is 'ems'" do
      let(:ext_management_system) { active_record_instance_double("ExtManagementSystem", :name => "emstest") }
      let(:filter_type) { "ems" }

      before do
        ExtManagementSystem.stub(:find).with(:all, {}).and_return([ext_management_system])
        post :schedule_form_filter_type_field_changed, params, session
      end

      it "responds with a filtered ext management system list" do
        json = JSON.parse(response.body)
        json["filtered_item_list"].should == ["emstest"]
      end
    end

    context "when the filter_type is 'cluster'" do
      let(:cluster) do
        active_record_instance_double(
          "EmsCluster",
          :name                => "clustertest",
          :v_parent_datacenter => "datacenter",
          :v_qualified_desc    => "desc"
        )
      end
      let(:filter_type) { "cluster" }

      before do
        bypass_rescue
        EmsCluster.stub(:find).with(:all, {}).and_return([cluster])
        post :schedule_form_filter_type_field_changed, params, session
      end

      it "responds with a filtered cluster list" do
        json = JSON.parse(response.body)
        json["filtered_item_list"].should == [%w(clustertest__datacenter desc)]
      end
    end

    context "when the filter_type is 'host'" do
      let(:host) { active_record_instance_double("Host", :name => "hosttest") }
      let(:filter_type) { "host" }

      before do
        Host.stub(:find).with(:all, {}).and_return([host])
        post :schedule_form_filter_type_field_changed, params, session
      end

      it "responds with a filtered host list" do
        json = JSON.parse(response.body)
        json["filtered_item_list"].should == ["hosttest"]
      end
    end
  end
end
