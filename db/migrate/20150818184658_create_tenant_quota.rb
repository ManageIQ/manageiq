class CreateTenantQuota < ActiveRecord::Migration[4.2]
  def change
    create_table :tenant_quotas do |t|
      t.belongs_to :tenant, :type => :bigint

      t.string     :name
      t.string     :unit
      t.float      :value

      t.timestamps :null => false
    end
  end
end
