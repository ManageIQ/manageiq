class CreateGenericObject < ActiveRecord::Migration
  def change
    create_table :generic_object_definitions do |t|
      t.string     :name
      t.string     :description
      t.text       :properties
      t.timestamps :null => false
    end

    create_table :generic_objects do |t|
      t.string     :name
      t.string     :uid
      t.belongs_to :generic_object_definition, :type => :bigint
      t.timestamps :null => false
    end
  end
end
