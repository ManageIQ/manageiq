class CreateSecurityContext < ActiveRecord::Migration
  def change
    create_table :security_contexts do |t|
      t.references :resource, :polymorphic => true, :type => :bigint
      t.string     :se_linux_user
      t.string     :se_linux_role
      t.string     :se_linux_type
      t.string     :se_linux_level
    end
  end
end
