class CreateCloudServices < ActiveRecord::Migration[5.0]
  def change
    create_table :cloud_services do |t|
      t.string     :ems_ref
      t.string     :source
      t.string     :executable_name
      t.string     :hostname
      t.string     :status
      t.boolean    :scheduling_disabled
      t.string     :scheduling_disabled_reason
      t.bigint     :ems_id
      t.references :host,              :type => :bigint
      t.references :system_service,    :type => :bigint
      t.references :availability_zone, :type => :bigint

      t.timestamps
    end
    add_index :cloud_services, :ems_id
  end
end
