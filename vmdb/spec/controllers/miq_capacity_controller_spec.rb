require "spec_helper"

describe MiqCapacityController do
  methods = ["util_get_node_info","bottleneck_get_node_info"]
  methods.each do |method|
    context "##{method}" do
      it "set correct right cell headers in #{method}" do
        mr = FactoryGirl.create(:miq_region, :description => "My Region")
        e = FactoryGirl.create(:ems_vmware, :name => "My Management System")
        cl = FactoryGirl.create(:ems_cluster, :name => "My Cluster")
        host = FactoryGirl.create(:host, :name => "My Host")
        ds = FactoryGirl.create(:storage_vmware, :name => "My Datastore")
        title_suffix = method == "util_get_node_info" ? "Utilization Trend Summary" : "Bottlenecks Summary"
        tree_nodes = Hash.new
        tree_nodes =  {
                        :region => {:active_node => "mr-#{MiqRegion.compress_id(mr.id)}", :title_prefix => "Region", :title => mr.description},
                        :e => {:active_node => "e-#{MiqRegion.compress_id(e.id)}", :title_prefix => "Provider", :title => e.name},
                        :cl => {:active_node => "c-#{MiqRegion.compress_id(cl.id)}", :title_prefix => "Cluster", :title => cl.name},
                        :host => {:active_node => "h-#{MiqRegion.compress_id(host.id)}", :title_prefix => "Host", :title => host.name},
                        :ds => {:active_node => "ds-#{MiqRegion.compress_id(ds.id)}", :title_prefix => "Datastore", :title => ds.name}
                      }
        tree_nodes.each do |key,node|
          controller.instance_variable_set(:@temp, {})
          controller.instance_variable_set(:@breadcrumbs, [])
          controller.instance_variable_set(:@sb, {
                                                    :trees => {
                                                                :utilization_tree => {:active_node => node[:active_node]},
                                                                :bottlenecks_tree => {:active_node => node[:active_node]}
                                                              },
                                                    :active_tree => method == "util_get_node_info" ? :utilization_tree : :bottlenecks_tree,
                                                    :bottlenecks => {:options => {}},
                                                    :util => {:options => {}}
                                                  }
                                          )
          controller.should_not_receive(:render)
          controller.send(method.to_sym, node[:active_node])
          assigns(:right_cell_text).should == "#{node[:title_prefix]} \"#{node[:title]}\" #{title_suffix}"
        end
      end
    end
  end
end
