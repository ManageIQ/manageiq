class AddStatusReasonAndCloudTenantToOrchestrationStacks < ActiveRecord::Migration[4.2]
  def change
    add_column :orchestration_stacks, :status_reason,   :text
    add_column :orchestration_stacks, :cloud_tenant_id, :bigint
  end
end
