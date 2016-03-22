class CreateEntitlements < ActiveRecord::Migration[5.0]
  def change
    create_table :entitlements do |t|
      t.bigint :miq_group_id
      t.bigint :miq_user_role_id

      t.timestamps
    end
  end
end
