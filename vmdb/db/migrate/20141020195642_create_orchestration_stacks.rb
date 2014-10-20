class CreateOrchestrationStacks < ActiveRecord::Migration
  def change
    create_table :orchestration_templates do |t|
      t.string   :name
      t.string   :type
      t.text     :description
      t.text     :content
      t.string   :ems_ref

      t.timestamps
    end

    add_index :orchestration_templates, :ems_ref, :unique => true

    create_table :orchestration_stacks do |t|
      t.string  :name
      t.string  :type
      t.text    :description
      t.string  :status
      t.string  :ems_ref
      t.string  :ancestry

      t.belongs_to :ems
      t.belongs_to :orchestration_template

      t.timestamps
    end

    add_index :orchestration_stacks, :orchestration_template_id
    add_index :orchestration_stacks, :ancestry

    add_column :vms,             :orchestration_stack_id, :bigint
    add_column :security_groups, :orchestration_stack_id, :bigint
    add_column :cloud_networks,  :orchestration_stack_id, :bigint

    create_table :orchestration_stack_parameters do |t|
      t.string :name
      t.text   :value

      t.belongs_to :stack
    end

    add_index :orchestration_stack_parameters, :stack_id

    create_table :orchestration_stack_outputs do |t|
      t.string :key
      t.text   :value
      t.text   :description

      t.belongs_to :stack
    end

    add_index :orchestration_stack_outputs, :stack_id

    create_table :orchestration_stack_resources do |t|
      t.string :name
      t.text   :description
      t.text   :logical_resource
      t.text   :physical_resource
      t.string :resource_category
      t.string :resource_status
      t.text   :resource_status_reason
      t.timestamp :last_updated

      t.belongs_to :stack
    end

    add_index :orchestration_stack_resources, :stack_id
  end
end
