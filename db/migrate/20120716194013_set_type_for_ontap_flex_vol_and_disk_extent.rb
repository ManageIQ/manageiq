class SetTypeForOntapFlexVolAndDiskExtent < ActiveRecord::Migration
  class MiqCimInstance < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    MiqCimInstance.where(:class_name => 'ONTAP_FlexVolExtent').update_all(:type => 'OntapFlexVolExtent')
    MiqCimInstance.where(:class_name => 'ONTAP_DiskExtent').update_all(:type => 'OntapDiskExtent')
  end

  def down
    MiqCimInstance.where(:type => 'OntapFlexVolExtent').update_all(:type => nil)
    MiqCimInstance.where(:type => 'OntapDiskExtent').update_all(:type => nil)
  end
end
