class CreateServices < ActiveRecord::Migration
  def up
    change_column :miq_queue, :task_id, :string

    change_table :service_resources do |t|
      t.string      :name
      t.belongs_to  :service,                       :type => :bigint
      t.belongs_to  :source,  :polymorphic => true, :type => :bigint
      t.rename      :service_or_template_id, :service_template_id
    end

    rename_table    :services_and_templates,  :service_templates

    change_table :service_templates do |t|
      t.boolean     :display
      t.rename      :service_or_template_id, :service_template_id
    end

    create_table :services do |t|
      t.string      :name
      t.string      :description
      t.string      :guid
      t.string      :type
      t.belongs_to  :service_template,              :type => :bigint
      t.text        :options
      t.boolean     :display
      t.timestamps
    end
  end

  def down
    remove_index :miq_queue, :name => "miq_queue_idx"
    change_column :miq_queue, :task_id, :string, :limit => 36

    if connection.adapter_name == "MySQL"
      # Handle issue where MySQL has a limited key size
      say_with_time('add_index(:miq_queue, [:state (100), :zone (100), :task_id, :queue_name (100), :role (100), :server_guid, :deliver_on, :priority, :id], {:name=>"miq_queue_idx"})') do
        connection.execute("CREATE INDEX `miq_queue_idx` ON `miq_queue` (`state` (100), `zone` (100), `task_id`, `queue_name` (100), `role` (100), `server_guid`, `deliver_on`, `priority`, `id`)")
      end
    else
      add_index :miq_queue, [:state, :zone, :task_id, :queue_name, :role, :server_guid, :deliver_on, :priority, :id], :name => "miq_queue_idx"
    end

    change_table :service_resources do |t|
      t.remove_belongs_to  :source,  :polymorphic => true
      t.remove      :name
      t.remove_belongs_to   :service
      t.rename      :service_template_id, :service_or_template_id
    end

    change_table :service_templates do |t|
      t.rename      :service_template_id, :service_or_template_id
      t.remove      :display
    end
    rename_table  :service_templates,   :services_and_templates

    drop_table      :services
  end
end
