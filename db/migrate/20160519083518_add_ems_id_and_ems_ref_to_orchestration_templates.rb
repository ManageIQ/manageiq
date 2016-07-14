class AddEmsIdAndEmsRefToOrchestrationTemplates < ActiveRecord::Migration[5.0]
  def change
    add_column :orchestration_templates, :ems_ref, :string
    add_column :orchestration_templates, :ems_id, :bigint

    add_index :orchestration_templates, :ems_id
  end
end
