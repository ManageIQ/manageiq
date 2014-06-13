class CreatePictures < ActiveRecord::Migration
  def up
    create_table :pictures do |t|
      t.belongs_to  :resource, :polymorphic => true
    end
  end

  def down
    drop_table :pictures
  end
end
