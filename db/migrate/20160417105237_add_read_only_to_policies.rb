class AddReadOnlyToPolicies < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_policies, :read_only, :boolean
    add_column :conditions,   :read_only, :boolean
  end
end
