require "spec_helper"

describe VmInfraController do
  describe ApplicationController::Explorer do
    context "#valid_active_node" do
      let(:active_tree) { :stcat_tree }

      it "root node" do
        active_node = "root"

        controller.instance_variable_set(:@sb, {:trees => {active_tree => {:active_node => active_node}}, :active_tree => active_tree})
        res = controller.send(:valid_active_node, active_node)
        controller.send(:flash_errors?).should_not be_true
        res.should == active_node
      end

      it "valid node" do
        rec = FactoryGirl.create(:service_template_catalog)
        active_node = "stc-#{rec.id}"

        controller.instance_variable_set(:@sb, {:trees => {active_tree => {:active_node => active_node}}, :active_tree => active_tree})
        res = controller.send(:valid_active_node, active_node)
        controller.send(:flash_errors?).should_not be_true
        res.should == active_node
      end

      it "node no longer exists" do
        rec = FactoryGirl.create(:service_template_catalog)
        active_node = "stc-#{rec.id + 1}"

        controller.instance_variable_set(:@sb, {:trees => {active_tree => {:active_node => active_node}}, :active_tree => active_tree})
        res = controller.send(:valid_active_node, active_node)
        controller.send(:flash_errors?).should be_true
        res.should == "root"
      end
    end

    context "#rbac_filtered_objects" do
      it "properly calls RBAC" do
        EvmSpecHelper.create_guid_miq_server_zone
        ems_folder = FactoryGirl.create(:ems_folder)
        ems = FactoryGirl.create(:ems_vmware, :ems_folders => [ems_folder])

        user = FactoryGirl.create(:user_admin)
        user.current_group.set_managed_filters([["/managed/service_level/gold"]])
        login_as user

        Rbac.should_receive(:search).with(:targets => [ems_folder], :results_format=>:objects).and_call_original

        controller.send(:rbac_filtered_objects, [ems_folder], :match_via_descendants => "VmOrTemplate")
      end
    end

    describe "#x_get_tree_roots" do
      let(:options) { {:count_only => count_only, :type => type} }

      context "when the options type is export" do
        let(:type) { :export }

        context "when the options count_only is true" do
          let(:count_only) { true }

          it "returns the count of the export children" do
            expect(controller.send(:x_get_tree_roots, options)).to eq(2)
          end
        end

        context "when the options count_only is false" do
          let(:count_only) { false }

          it "returns the export children" do
            expect(controller.send(:x_get_tree_roots, options)).to eq(
              [{
                :id    => "exportcustomreports",
                :tree  => "export_tree",
                :text  => "Custom Reports",
                :image => "report"
              }, {
                :id    => "exportwidgets",
                :tree  => "export_tree",
                :text  => "Widgets",
                :image => "report"
              }]
            )
          end
        end
      end
    end

    context "#x_get_tree_region_kids" do
      it "does not return Cloud Providers nodes for Utilization tree" do
        MiqRegion.seed
        region = MiqRegion.my_region
        ems_cloud = FactoryGirl.create(:ems_amazon)
        ems_infra = FactoryGirl.create(:ems_redhat)
        controller.instance_variable_set(:@sb, {:trees => {:utilization_tree => {:active_node => "root"}}, :active_tree => :utilization_tree})
        options = {
                    :tree => :utilization_tree,
                    :type => :utilization,
                    :parent => region
                  }

        objects = controller.send(:x_get_tree_region_kids, region, options)
        objects.should have(1).items
      end
    end

    context "#x_get_tree_custom_kids" do
      before(:each) do
        MiqRegion.seed
        @region = MiqRegion.my_region
      end

      it "Return only Infra Providers nodes for Utilization tree" do
        ems_cloud = FactoryGirl.create(:ems_amazon)
        ems_infra = FactoryGirl.create(:ems_redhat)
        folder_node_id = {:id => "folder_e_xx-#{MiqRegion.compress_id(@region.id)}"}
        controller.instance_variable_set(:@sb, {:trees => {:utilization_tree => {:active_node => "root"}}, :active_tree => :utilization_tree})
        options = {
                    :tree => :utilization_tree,
                    :type => :utilization,
                    :parent => @region
                  }

        objects = controller.send(:x_get_tree_custom_kids, folder_node_id , options)
        objects.should have(1).items
        objects.first[:id].should_not == ems_cloud.id
        objects.first[:id].should == ems_infra.id
      end
    end

    context "#x_settings_changed" do
      let(:user) { FactoryGirl.create(:user, :userid => 'wilma', :settings => {}) }
      before(:each) do
        set_user_privileges user
      end

      it "sets the width of left pane for session's user" do
        session[:settings] = {}
        User.stub(:find_by_userid).and_return(user)

        controller.instance_variable_set(:@settings,  {})
        user.should_receive(:save)
        width = '100'
        get :x_settings_changed, :width => width

        user.settings[:explorer][controller.controller_name][:width].should == width
        session[:settings][:explorer][controller.controller_name][:width].should == width
      end
    end

    context '#x_history_add_item' do
      def make_item(i)
        {
          :id      => "#{i}_id",
          :action  => "#{i}_action",
          :button  => "#{i}_button",
          :display => "#{i}_display",
          :item    => "#{i}_item",
        }
      end

      before(:each) do
        sb = {
          :active_tree => 'foo_tree',
          :history => {
            'foo_tree' => (1..11).collect { |i| make_item(i) }
          }
        }
        controller.instance_variable_set(:@sb, sb)
      end

      it 'adds new item into the history' do
        controller.send(:x_history_add_item, make_item(12))

        assigns(:sb)[:history]['foo_tree'].first[:id].should == '12_id'

        assigns(:sb)[:history]['foo_tree'].find { |item|
          item[:id] == '11_id'
        }.should be_nil
      end

      it 'it removes duplicate items from the history' do
        item = make_item(1).update( :foo => 'bar' )

        controller.send(:x_history_add_item, item)

        items = assigns(:sb)[:history]['foo_tree'].find_all { |item|
          item[:id] == '1_id'
        }

        items.length.should == 1
        items[0][:foo].should == 'bar'
      end
    end
  end
end
