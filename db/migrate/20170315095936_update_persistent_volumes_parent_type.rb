class UpdatePersistentVolumesParentType < ActiveRecord::Migration[5.0]
  class ContainerVolume < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    ContainerVolume.where(:parent_type => 'ManageIQ::Providers::ContainerManager')
                   .update_all(:parent_type => 'ExtManagementSystem')
  end

  def down
    ContainerVolume.where(:parent_type => 'ExtManagementSystem')
                   .update_all(:parent_type => 'ManageIQ::Providers::ContainerManager')
  end
end
