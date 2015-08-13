class CreateContainerImages < ActiveRecord::Migration
  def up
    create_table :container_images do |t|
      t.string     :tag
      t.string     :name
      t.string     :image_ref
      t.belongs_to :container_image_registry, :type => :bigint
      t.belongs_to :ems, :type => :bigint
    end
  end

  def down
    drop_table :container_images
  end
end
