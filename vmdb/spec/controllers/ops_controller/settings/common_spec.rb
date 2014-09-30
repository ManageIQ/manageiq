require "spec_helper"

describe OpsController do
  context "OpsController::Settings::Common" do
    context "SmartProxy Affinity" do
      before do
        @zone = FactoryGirl.create(:zone, :name => 'zone1')

        @storage1 = FactoryGirl.create(:storage)
        @storage2 = FactoryGirl.create(:storage)

        @host1 = FactoryGirl.create(:host, :name => 'host1', :storages => [@storage1])
        @host2 = FactoryGirl.create(:host, :name => 'host2', :storages => [@storage2])

        @ems = FactoryGirl.create(:ext_management_system, :hosts => [@host1, @host2], :zone => @zone)

        @svr1 = FactoryGirl.create(:miq_server, :name => 'svr1', :zone => @zone)
        @svr2 = FactoryGirl.create(:miq_server, :name => 'svr2', :zone => @zone)

        @svr1.vm_scan_host_affinity = [@host1]
        @svr2.vm_scan_host_affinity = [@host2]
        @svr1.vm_scan_storage_affinity = [@storage1]
        @svr2.vm_scan_storage_affinity = [@storage2]
        MiqServer.any_instance.stub(:is_a_proxy? => true)

        tree_hash = {
          :trees       => {
            :settings_tree => {
              :active_node => "z-#{@zone.id}"
            }
          },
          :active_tree => :settings_tree,
          :active_tab  => 'settings_smartproxy_affinity'
        }
        controller.instance_variable_set(:@sb, tree_hash)
        controller.instance_variable_set(:@selected_zone, @zone)

        @temp = {}
        controller.instance_variable_set(:@temp, @temp)

        controller.send(:smartproxy_affinity_set_form_vars)
        @edit = session[:edit]
      end

      context "#build_smartproxy_affinity_tree" do
        it "should build a SmartProxy Affinity tree" do
          tree = controller.send(:build_smartproxy_affinity_tree, @zone)
          tree.should be == [
            {
              :key      => @svr1.id.to_s,
              :icon     => "evm_server.png",
              :title    => "Server: #{@svr1.name} [#{@svr1.id}]",
              :expand   => true,
              :children => [
                {
                  :key      => "#{@svr1.id}__host",
                  :icon     => "host.png",
                  :title    => "Hosts",
                  :children => [
                    {
                      :key    => "#{@svr1.id}__host_#{@host1.id}",
                      :icon   => "host.png",
                      :title  => @host1.name,
                      :select => true
                    },
                    {
                      :key    => "#{@svr1.id}__host_#{@host2.id}",
                      :icon   => "host.png",
                      :title  => @host2.name,
                      :select => false
                    }
                  ]
                },
                {
                  :key      => "#{@svr1.id}__storage",
                  :icon     => "storage.png",
                  :title    => "Datastores",
                  :children => [
                    {
                      :key    => "#{@svr1.id}__storage_#{@storage1.id}",
                      :icon   => "storage.png",
                      :title  => @storage1.name,
                      :select => true
                    },
                    {
                      :key    => "#{@svr1.id}__storage_#{@storage2.id}",
                      :icon   => "storage.png",
                      :title  => @storage2.name,
                      :select => false
                    }
                  ]
                }
              ]
            },
            {
              :key      => @svr2.id.to_s,
              :icon     => "evm_server.png",
              :title    => "Server: #{@svr2.name} [#{@svr2.id}]",
              :expand   => true,
              :children => [
                {
                  :key      => "#{@svr2.id}__host",
                  :icon     => "host.png",
                  :title    => "Hosts",
                  :children => [
                    {
                      :key    => "#{@svr2.id}__host_#{@host1.id}",
                      :icon   => "host.png",
                      :title  => @host1.name,
                      :select => false
                    },
                    {
                      :key    => "#{@svr2.id}__host_#{@host2.id}",
                      :icon   => "host.png",
                      :title  => @host2.name,
                      :select => true
                    }
                  ]
                },
                {
                  :key      => "#{@svr2.id}__storage",
                  :icon     => "storage.png",
                  :title    => "Datastores",
                  :children => [
                    {
                      :key    => "#{@svr2.id}__storage_#{@storage1.id}",
                      :icon   => "storage.png",
                      :title  => @storage1.name,
                      :select => false
                    },
                    {
                      :key    => "#{@svr2.id}__storage_#{@storage2.id}",
                      :icon   => "storage.png",
                      :title  => @storage2.name,
                      :select => true
                    }
                  ]
                }
              ]
            }
          ]
        end
      end

      context "#smartproxy_affinity_field_changed" do
        before do
          controller.should_receive(:render)
        end

        it "should select a host when checked" do
          controller.params = {:id => "#{@svr1.id}__host_#{@host2.id}", :check => '1'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:hosts].to_a.should include(@host2.id)
        end

        it "should deselect a host when unchecked" do
          controller.params = {:id => "#{@svr1.id}__host_#{@host1.id}", :check => '0'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:hosts].to_a.should_not include(@host1.id)
        end

        it "should select a datastore when checked" do
          controller.params = {:id => "#{@svr1.id}__storage_#{@storage2.id}", :check => '1'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:storages].to_a.should include(@storage2.id)
        end

        it "should deselect a datastore when unchecked" do
          controller.params = {:id => "#{@svr1.id}__storage_#{@storage1.id}", :check => '0'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:storages].to_a.should_not include(@storage1.id)
        end

        it "should select all child hosts when checked" do
          controller.params = {:id => "#{@svr1.id}__host", :check => '1'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:hosts].to_a.sort.should be == [@host1.id, @host2.id]
        end

        it "should deselect all child hosts when unchecked" do
          controller.params = {:id => "#{@svr1.id}__host", :check => '0'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:hosts].to_a.should be == []
        end

        it "should select all child datastores when checked" do
          controller.params = {:id => "#{@svr1.id}__storage", :check => '1'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:storages].to_a.sort.should be == [@storage1.id, @storage2.id]
        end

        it "should deselect all child datastores when unchecked" do
          controller.params = {:id => "#{@svr1.id}__storage", :check => '0'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:storages].to_a.should be == []
        end

        it "should select all child hosts and datastores when checked" do
          controller.params = {:id => "#{@svr1.id}", :check => '1'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:hosts].to_a.sort.should be == [@host1.id, @host2.id]
          @edit[:new][:servers][@svr1.id][:storages].to_a.sort.should be == [@storage1.id, @storage2.id]
        end

        it "should deselect all child hosts and datastores when checked" do
          controller.params = {:id => "#{@svr1.id}", :check => '0'}
          controller.smartproxy_affinity_field_changed
          @edit[:new][:servers][@svr1.id][:hosts].to_a.should be == []
          @edit[:new][:servers][@svr1.id][:storages].to_a.should be == []
        end
      end

      context "#smartproxy_affinity_update" do
        it "updates the SmartProxy host affinities" do
          @svr1.vm_scan_host_affinity = []
          @svr2.vm_scan_host_affinity = []

          # Commit the in-progress edit state (i.e. the initial state)
          controller.send(:smartproxy_affinity_update)
          @svr1.vm_scan_host_affinity.should be == [@host1]
          @svr2.vm_scan_host_affinity.should be == [@host2]
        end

        it "updates the SmartProxy storage affinities" do
          @svr1.vm_scan_storage_affinity = []
          @svr2.vm_scan_storage_affinity = []

          # Commit the in-progress edit state (i.e. the initial state)
          controller.send(:smartproxy_affinity_update)
          @svr1.vm_scan_storage_affinity.should be == [@storage1]
          @svr2.vm_scan_storage_affinity.should be == [@storage2]
        end
      end
    end
  end
end
