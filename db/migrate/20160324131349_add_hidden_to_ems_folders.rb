class AddHiddenToEmsFolders < ActiveRecord::Migration[5.0]
  class EmsFolder < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def change
    add_column :ems_folders, :hidden, :boolean
  end
end
