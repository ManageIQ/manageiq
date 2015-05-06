class AddStatusReasonAndCloudTenantToOrchestrationStacks < ActiveRecord::Migration
  def change
    add_column :orchestration_stacks, :status_reason,   :text
    add_column :orchestration_stacks, :cloud_tenant_id, :bigint
  end
end
