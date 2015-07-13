class AddTypeToMiqCimInstances < ActiveRecord::Migration
  class MiqCimInstance < ActiveRecord::Base
    self.inheritance_column = :_type_disabled  # disable STI

    SUPER_CLASSES = [
      'CIM_StorageExtent',
      'CIM_CompositeExtent',
      'CIM_LogicalDisk',
      'CIM_StorageVolume',
      'CIM_ComputerSystem',
      'SNIA_FileShare',
      'SNIA_LocalFileSystem',
      'MIQ_CimVirtualDisk',
      'MIQ_CimVirtualMachine',
      'MIQ_CimDatastore',
      'MIQ_CimHostSystem'
    ]

    def class_hier_array
      chs = class_hier
      chs = chs[1..-2] if chs
      return chs.split('/') if chs
      return []
    end

    def typeFromClassHier
      class_hier_array.each { |c| return typeFromClassName(c) if SUPER_CLASSES.include?(c) }
      return nil
    end

    def typeFromClassName(className)
      return className.underscore.camelize
    end
  end

  def self.up
    add_column :miq_cim_instances,  :type,  :string

    say_with_time("Update MiqCimInstance type") do
      MiqCimInstance.all.each do |ci|
        t = ci.typeFromClassHier
        ci.update_attribute(:type, t) if t
      end
    end
  end

  def self.down
    remove_column :miq_cim_instances, :type
  end
end
