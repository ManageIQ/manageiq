require "spec_helper"

describe VmInfraController do
  describe ApplicationController::Explorer do
    context "#valid_active_node" do
      let(:active_tree) { :stcat_tree }

      it "root node" do
        active_node = "root"

        controller.instance_variable_set(:@sb, :trees => {active_tree => {:active_node => active_node}}, :active_tree => active_tree)
        res = controller.send(:valid_active_node, active_node)
        controller.send(:flash_errors?).should_not be_true
        res.should == active_node
      end

      it "valid node" do
        rec = FactoryGirl.create(:service_template_catalog)
        active_node = "stc-#{rec.id}"

        controller.instance_variable_set(:@sb, :trees => {active_tree => {:active_node => active_node}}, :active_tree => active_tree)
        res = controller.send(:valid_active_node, active_node)
        controller.send(:flash_errors?).should_not be_true
        res.should == active_node
      end

      it "node no longer exists" do
        rec = FactoryGirl.create(:service_template_catalog)
        active_node = "stc-#{rec.id + 1}"

        controller.instance_variable_set(:@sb, :trees => {active_tree => {:active_node => active_node}}, :active_tree => active_tree)
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

        Rbac.should_receive(:search).with(:targets => [ems_folder], :results_format => :objects).and_call_original

        controller.send(:rbac_filtered_objects, [ems_folder], :match_via_descendants => "VmOrTemplate")
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
          :history     => {
            'foo_tree' => (1..11).collect { |i| make_item(i) }
          }
        }
        controller.instance_variable_set(:@sb, sb)
      end

      it 'adds new item into the history' do
        controller.send(:x_history_add_item, make_item(12))

        assigns(:sb)[:history]['foo_tree'].first[:id].should == '12_id'

        assigns(:sb)[:history]['foo_tree'].find do |item|
          item[:id] == '11_id'
        end.should be_nil
      end

      it 'it removes duplicate items from the history' do
        item = make_item(1).update(:foo => 'bar')

        controller.send(:x_history_add_item, item)

        items = assigns(:sb)[:history]['foo_tree'].find_all do |item|
          item[:id] == '1_id'
        end

        items.length.should == 1
        items[0][:foo].should == 'bar'
      end
    end
  end
end

describe ReportController do
  context '#tree_add_child_nodes' do
    it 'calls tree_add_child_nodes TreeBuilder method' do
      widget = FactoryGirl.create(:miq_widget, :description => "Foo", :title => "Foo", :content_type => "report")
      controller.instance_variable_set(:@sb,
                                       :trees       => {:widgets_tree => {:active_node => "root",
                                                                          :klass_name  => "TreeBuilderReportWidgets",
                                                                          :open_nodes  => []}},
                                       :active_tree => :widgets_tree

                                      )
      TreeBuilderReportWidgets.new('widgets_tree', 'widgets', {})
      nodes = controller.send(:tree_add_child_nodes, 'xx-r')
      nodes.should eq([{:key     => "-#{controller.to_cid(widget.id)}",
                        :title   => "Foo",
                        :icon    => "report_widget.png",
                        :tooltip => "Foo"}]
                     )
    end
  end
end
