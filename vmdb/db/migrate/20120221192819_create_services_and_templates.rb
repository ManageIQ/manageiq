class CreateServicesAndTemplates < ActiveRecord::Migration
  def up
    drop_table    :services
    remove_column :vms, :service_id

    create_table :services_and_templates do |t|
      t.string     :name
      t.string     :description
      t.string     :guid
      t.string     :type
      t.belongs_to :service_or_template
      t.text       :options
      t.timestamps
    end

    create_table :service_resources do |t|
      t.belongs_to :service_or_template
      t.belongs_to :resource,    :polymorphic => true
      t.integer    :group_idx,   :default => 0
      t.integer    :scaling_min, :default => 1
      t.integer    :scaling_max, :default => -1
      t.string     :start_action
      t.integer    :start_delay
      t.string     :stop_action
      t.integer    :stop_delay
      t.timestamps
    end
  end

  def down
    drop_table    :service_resources
    drop_table    :services_and_templates

    create_table  :services do |t|
      t.string    :name
      t.datetime  :created_on
      t.datetime  :updated_on
      t.string    :created_by
      t.string    :icon
    end

    add_column    :vms, :service_id, :bigint
    add_index     "vms", ["service_id"]
  end
end
