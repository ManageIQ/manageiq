class OrchestrationTemplateRenameEmsRefToMd5AndDropUnique < ActiveRecord::Migration
  def up
    remove_index  :orchestration_templates, :ems_ref
    rename_column :orchestration_templates, :ems_ref, :md5
    add_index     :orchestration_templates, :md5
  end

  def down
    remove_index  :orchestration_templates, :md5
    rename_column :orchestration_templates, :md5, :ems_ref
    add_index     :orchestration_templates, :ems_ref, :unique => true
  end
end
