class CreateContainerImageRegistries < ActiveRecord::Migration
  def up
    create_table :container_image_registries do |t|
      t.string     :name  # Never used but all entities are assumed to have a name.
      t.string     :host
      t.string     :port
      t.belongs_to :ems, :type => :bigint
    end
  end

  def down
    drop_table :container_image_registries
  end
end
