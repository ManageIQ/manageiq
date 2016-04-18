class CreateContainerLabelTagMappings < ActiveRecord::Migration[5.0]
  def change
    create_table :container_label_tag_mappings do |t|
      t.string :labeled_resource_type
      t.string :label_name
      t.text :label_value
      t.belongs_to :tag, :type => :bigint

      t.timestamps
    end
  end
end
