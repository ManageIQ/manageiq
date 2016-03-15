describe MiqCapacityController do
  methods = ["util_get_node_info", "bottleneck_get_node_info"]
  methods.each do |method|
    context "##{method}" do
      it "set correct right cell headers in #{method}" do
        mr = FactoryGirl.create(:miq_region, :description => "My Region")
        e = FactoryGirl.create(:ems_vmware, :name => "My Management System")
        cl = FactoryGirl.create(:ems_cluster, :name => "My Cluster")
        host = FactoryGirl.create(:host, :name => "My Host")
        ds = FactoryGirl.create(:storage_vmware, :name => "My Datastore")
        title_suffix = method == "util_get_node_info" ? "Utilization Trend Summary" : "Bottlenecks Summary"
        tree_nodes = {:region => {:active_node  => "mr-#{MiqRegion.compress_id(mr.id)}",
                                  :title_prefix => "Region",
                                  :title        => mr.description},
                      :e      => {:active_node  => "e-#{MiqRegion.compress_id(e.id)}",
                                  :title_prefix => "Provider",
                                  :title        => e.name},
                      :cl     => {:active_node  => "c-#{MiqRegion.compress_id(cl.id)}",
                                  :title_prefix => "Cluster / Deployment Role",
                                  :title        => cl.name},
                      :host   => {:active_node  => "h-#{MiqRegion.compress_id(host.id)}",
                                  :title_prefix => "Host / Node",
                                  :title        => host.name},
                      :ds     => {:active_node  => "ds-#{MiqRegion.compress_id(ds.id)}",
                                  :title_prefix => "Datastore",
                                  :title        => ds.name}
                      }
        tree_nodes.each do |_key, node|
          controller.instance_variable_set(:@breadcrumbs, [])
          controller.instance_variable_set(:@sb,                                                     :trees       => {
                                             :utilization_tree => {:active_node => node[:active_node]},
                                             :bottlenecks_tree => {:active_node => node[:active_node]}
                                           },
                                                                                                     :active_tree => method == "util_get_node_info" ? :utilization_tree : :bottlenecks_tree,
                                                                                                     :bottlenecks => {:options => {}},
                                                                                                     :util        => {:options => {}}
                                          )
          expect(controller).not_to receive(:render)
          controller.send(method.to_sym, node[:active_node])
          expect(assigns(:right_cell_text)).to eq("#{node[:title_prefix]} \"#{node[:title]}\" #{title_suffix}")
        end
      end
    end
  end
end

describe MiqCapacityController do
  context "#find_filtered" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      set_user_privileges

      @host1 = FactoryGirl.create(:host, :name => 'Host1')
      @host2 = FactoryGirl.create(:host, :name => 'Host2')

      @vm1 = FactoryGirl.create(:vm_vmware, :name => 'Name1', :host => @host1)
      @vm2 = FactoryGirl.create(:vm_vmware, :name => 'Name2', :host => @host2)
      @vm3 = FactoryGirl.create(:vm_vmware, :name => 'Name3', :host => @host1)
      @vm4 = FactoryGirl.create(:vm_vmware, :name => 'Name4', :host => @host1)
    end

    it 'displays all Vms' do
      allow(controller).to receive(:render)
      controller.instance_variable_set(:@sb, :planning => {:vms => {}, :options => {}})
      controller.instance_variable_set(:@_params, :filter_typ => "all")
      controller.send(:planning_option_changed)
      sb = controller.instance_variable_get(:@sb)
      expect(sb[:planning][:vms]).to eq(@vm1.id.to_s => @vm1.name,
                                        @vm2.id.to_s => @vm2.name,
                                        @vm3.id.to_s => @vm3.name,
                                        @vm4.id.to_s => @vm4.name)
    end

    it 'displays Vms filtered by host' do
      allow(controller).to receive(:render)
      controller.instance_variable_set(:@sb, :planning => {:vms => {}, :options => {}})
      controller.instance_variable_set(:@_params, :filter_typ => "host", :filter_value => @host1.id)
      controller.send(:planning_option_changed)
      sb = controller.instance_variable_get(:@sb)
      expect(sb[:planning][:vms]).to eq(@vm1.id.to_s => @vm1.name, @vm3.id.to_s => @vm3.name, @vm4.id.to_s => @vm4.name)
    end
  end
end
