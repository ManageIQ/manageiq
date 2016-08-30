class MigratePortsToPortRangesInLoadBalancerListener < ActiveRecord::Migration[5.0]
  class LoadBalancerListener < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("Migrating LoadBalancerListeners instance_port values to instance_port_range...") do
      LoadBalancerListener.where.not(:instance_port => nil).each do |x|
        x.update(:instance_port_range => x.instance_port..x.instance_port,
                 :instance_port       => nil)
      end
    end
    say_with_time("Migrating LoadBalancerListeners load_balancer_port values to load_balancer_port_range...") do
      LoadBalancerListener.where.not(:load_balancer_port => nil).each do |x|
        x.update(:load_balancer_port_range => x.load_balancer_port..x.load_balancer_port,
                 :load_balancer_port       => nil)
      end
    end
  end

  def down
    say_with_time("Migrating LoadBalancerListeners load_balancer_port_range values to load_balancer_port"\
        " (where possible)...") do
      LoadBalancerListener.where.not(:load_balancer_port_range => nil).each do |x|
        x.update(:load_balancer_port => x.load_balancer_port_range.begin) if x.load_balancer_port_range.size == 1
        x.update(:load_balancer_port_range => nil)
      end
    end
    say_with_time("Migrating LoadBalancerListeners instance_port_range values to instance_port (where possible)...") do
      LoadBalancerListener.where.not(:instance_port_range => nil).each do |x|
        x.update(:instance_port => x.instance_port_range.begin) if x.instance_port_range.size == 1
        x.update(:instance_port_range => nil)
      end
    end
  end
end
