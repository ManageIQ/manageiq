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

      it "invalid node" do
        pending("handling invalid nodes") do
          active_node = "xxx"

          controller.instance_variable_set(:@sb, {:trees => {active_tree => {:active_node => active_node}}, :active_tree => active_tree})
          res = controller.send(:valid_active_node, active_node)
          controller.send(:flash_errors?).should be_true
          res.should == "root"
        end
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

    context "#model_from_nodetype" do
      it "valid model node" do
        res = controller.send(:model_from_nodetype, "v")
        res.should == Vm
      end

      it "Invalid model node" do
        lambda { controller.send(:model_from_nodetype, "bad") }.should raise_error(RuntimeError, "No Class found for explorer tree node type 'bad'")
      end
    end

    context "#nodetype_from_model" do
      it "valid node as string" do
        res = controller.send(:nodetype_from_model, "Vm")
        res.should == "v"
      end

      it "valid node as class" do
        res = controller.send(:nodetype_from_model, Vm)
        res.should == "v"
      end

      it "invalid node type" do
        lambda { controller.send(:nodetype_from_model, "bad") }.should raise_error(RuntimeError, "No explorer tree node type found for 'bad'")
      end
    end

    context "#x_build_node" do
      before :each do
        controller.instance_variable_set(:@sb, {:trees => {:utilization_tree => {:active_node => nil, :open_nodes => []}}})
      end

      it "valid Cluster node" do
        cluster = FactoryGirl.create(:ems_cluster, :name => "My Cluster")
        pid     = "parent_id"
        options = {
            :tree   => :utilization_tree,
            :type   => :utilization
        }

        node_array = controller.send(:x_build_node, cluster, pid, options)
        node = node_array.first

        node[:key].should eq("c-#{MiqRegion.compress_id(cluster.id)}")
        node[:title].should eq(cluster.name)
        node[:icon].should eq("cluster.png")
        node[:tooltip].should eq("Cluster: #{cluster.name}")
      end

      it "valid Host node" do
        host = FactoryGirl.create(:host, :name => "My Host")
        pid     = "parent_id"
        options = {
            :tree   => :utilization_tree,
            :type   => :utilization
        }

        node_array = controller.send(:x_build_node, host, pid, options)
        node = node_array.first

        node[:key].should eq("h-#{MiqRegion.compress_id(host.id)}")
        node[:title].should eq(host.name)
        node[:icon].should eq("host.png")
        node[:tooltip].should eq("Host: #{host.name}")
      end
    end

    context "#x_get_tree_ems_kids" do
      it "returns a valid utilization Clusters folder hash" do
        ems = FactoryGirl.create(:ems_redhat)
        cluster = FactoryGirl.create(:ems_cluster)
        ems.ems_clusters = [cluster]
        options = {
          :tree   => :utilization_tree,
          :type   => :utilization,
          :parent => ems
        }

        objects = controller.send(:x_get_tree_ems_kids, ems, options)
        object = objects.first

        object[:id].should    == "folder_c_xx-#{MiqRegion.compress_id(ems.id)}"
        object[:text].should  == "Clusters"
        object[:image].should == "folder"
        object[:tip].should   == "Clusters (Click to open)"
      end
    end

    context "#x_get_tree_cluster_kids" do
      it "does not return a Vm under Cluster node" do
        cluster = FactoryGirl.create(:ems_cluster)
        host = FactoryGirl.create(:host)
        vm = FactoryGirl.create(:vm_vmware)
        cluster.hosts = [host]
        cluster.vms = [vm]
        controller.instance_variable_set(:@sb, {:trees => {:utilization_tree => {:active_node => "root"}}, :active_tree => :utilization_tree})
        options = {
            :tree => :utilization_tree,
            :type => :utilization,
            :parent => cluster
        }

        objects = controller.send(:x_get_tree_cluster_kids, cluster, options)
        objects.each do |object|
          object.should_not be_a_kind_of(VmOrTemplate)
          object.should be_a_kind_of(Host)
        end
      end
    end

    context "#x_get_tree_host_kids" do
      it "does not return child nodes for Host node in Utilization tree" do
        host = FactoryGirl.create(:host_with_default_resource_pool_with_vms)
        controller.instance_variable_set(:@sb, {:trees => {:utilization_tree => {:active_node => "root"}}, :active_tree => :utilization_tree})
        options = {
            :tree => :utilization_tree,
            :type => :utilization,
            :parent => host
        }

        objects = controller.send(:x_get_tree_host_kids, host, options)
        objects.should == []
      end
    end

    context "#rbac_filtered_objects" do
      it "properly calls RBAC" do
        ems_folder = FactoryGirl.create(:ems_folder)
        ems = FactoryGirl.create(:ems_vmware, :ems_folders => [ems_folder])

        user = FactoryGirl.create(:user_admin)
        user.current_group.set_managed_filters([["/managed/service_level/gold"]])
        User.stub(:current_user => user)

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

      it "Return Zones only in My Region" do
        my_region_zone = FactoryGirl.create(:zone)
        non_my_region_zone = FactoryGirl.create(:zone, :id => "40", :name => "Zone2")
        controller.instance_variable_set(:@sb, {:trees =>
                                                    {:settings_tree => {:active_node => "root"}},
                                                :active_tree => :utilization_tree})
        options = {
            :tree => :settings_tree,
            :type => :settings,
            :parent => @region
        }
        object = {:id => "z"}
        objects = controller.send(:x_get_tree_custom_kids, object , options)
        objects.each do |o|
          o.miq_region.id.should == @region.id
        end
      end
    end

    context "#x_settings_changed" do
      before(:each) do
        set_user_privileges
      end

      it "sets the width of left pane for session's user" do
        user = FactoryGirl.create(:user, :userid => 'wilma', :settings => {})
        session[:userid]   = user.userid
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
