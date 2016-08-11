class AddStatusAndStatusReasonToLoadBalancerHealthCheckMembers < ActiveRecord::Migration[5.0]
  def change
    add_column :load_balancer_health_check_members, :status, :string
    add_column :load_balancer_health_check_members, :status_reason, :string
  end
end
