require 'yaml'

module MiqStorageDefs
    extend ActiveSupport::Concern

  STORAGE_UPDATE_OK           = 0
  STORAGE_UPDATE_NO_AGENT         = 1
  STORAGE_UPDATE_AGENT_OK_NO_INSTANCE   = 2
  STORAGE_UPDATE_AGENT_INACCESSIBLE   = 3
  STORAGE_UPDATE_NEW            = 4
  STORAGE_UPDATE_IN_PROGRESS        = 5
  STORAGE_UPDATE_PENDING          = 6
  STORAGE_UPDATE_FAILED         = 7
  STORAGE_UPDATE_BRIDGE_ASSOCIATIONS    = 8
  STORAGE_UPDATE_ASSOCIATION_SHORTCUTS  = 9
  STORAGE_UPDATE_ASSOCIATION_CLEANUP    = 10

  CIM_CLASS_HIER_FILE = File.join(File.dirname(__FILE__), "cim_class_hier.yml")
  CIM_CLASS_HIER = YAML.load_file(CIM_CLASS_HIER_FILE)

  module ClassMethods
    def cim_classes_based_on(cim_class_name)
      return CIM_CLASSES_BASED_ON[cim_class_name] || cim_class_name
    end
  end

  def self.classes_based_on
    cbo = Hash.new
    hier_arrays = CIM_CLASS_HIER.values.collect(&:dup)

    more = true
    while more do
      more = false
      hier_arrays.each do |ha|
        next if ha.empty?
        class_name = ha.last
        cbo[class_name] = [] if cbo[class_name].nil?
        cbo[class_name] = (cbo[class_name] + ha).uniq
        ha.pop
        more = true
      end
    end
    return cbo
  end

  CIM_CLASSES_BASED_ON = self.classes_based_on
end
