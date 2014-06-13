class AddOwnerToServices < ActiveRecord::Migration
  def change
    add_column :services,           :evm_owner_id, :bigint
    add_column :services,           :miq_group_id, :bigint
    add_column :services,           :service_type, :string

    add_column :service_templates,  :evm_owner_id, :bigint
    add_column :service_templates,  :miq_group_id, :bigint
    add_column :service_templates,  :service_type, :string
  end
end
