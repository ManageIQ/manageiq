class CreateTenantQuota < ActiveRecord::Migration
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
