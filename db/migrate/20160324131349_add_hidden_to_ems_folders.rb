class AddHiddenToEmsFolders < ActiveRecord::Migration[5.0]
  class EmsFolder < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :ems_folders, :hidden, :boolean

    say_with_time('Setting ems_folders.hidden to false') do
      EmsFolder.update_all(:hidden => false)
    end
  end

  def down
    remove_column :ems_folders, :hidden
  end
end
