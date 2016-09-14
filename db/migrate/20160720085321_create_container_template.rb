class CreateContainerTemplate < ActiveRecord::Migration[5.0]
  def change
    create_table :container_templates do |t|
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :ems_created_on
      t.string     :resource_version
      t.belongs_to :ems, :type => :bigint
      t.belongs_to :container_project, :type => :bigint
      t.text       :objects
      t.timestamps
    end

    create_table :container_template_parameters do |t|
      t.string     :name
      t.timestamp  :ems_created_on
      t.string     :display_name
      t.string     :description
      t.string     :value
      t.string     :generate
      t.string     :from
      t.boolean    :required
      t.belongs_to :container_template, :type => :bigint
      t.timestamps
    end
  end
end
