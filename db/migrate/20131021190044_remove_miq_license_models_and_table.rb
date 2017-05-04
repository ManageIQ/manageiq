class RemoveMiqLicenseModelsAndTable < ActiveRecord::Migration[4.2]
  def up
    drop_table :miq_license_contents
  end

  def down
    create_table :miq_license_contents do |t|
      t.text     :contents
      t.boolean  :active
      t.datetime :created_on
      t.datetime :updated_on
    end
  end
end
