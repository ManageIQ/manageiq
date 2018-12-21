module Vmdb
  module Inflections
    def self.load_inflections
      @loaded ||= begin
        load_core_inflections
        load_plugin_inflections
        true
      end
    end

    def self.load_core_inflections
      # Add new inflection rules using the following format
      # (all these examples are active by default):
      # ActiveSupport::Inflector.inflections do |inflect|
      #   inflect.plural /^(ox)$/i, '\1en'
      #   inflect.singular /^(ox)en/i, '\1'
      #   inflect.irregular 'person', 'people'
      #   inflect.uncountable %w( fish sheep )
      # end
      ActiveSupport::Inflector.inflections do |inflect|
        inflect.singular(/(base)s$/i, '\1') # Override rails default: "bases".singularize => "base" not "basis"
        inflect.singular(/class$/, "class")
        inflect.singular(/Class$/, "Class")
        inflect.singular(/OsProcess$/, "OsProcess")
        inflect.singular(/osprocess$/, "osprocess")
        inflect.singular(/vms_and_templates$/, "vm_or_template")
        inflect.plural(/vm_or_template$/, "vms_and_templates")
        inflect.singular(/VmsAndTemplates$/, "VmOrTemplate")
        inflect.plural(/VmOrTemplate$/, "VmsAndTemplates")
        inflect.singular(/Indexes$/, "Index")       # for Class name(s)
        inflect.plural(/Index$/, "Indexes")         # for Class name(s)
        inflect.singular(/indexes$/, "index")       # for table name(s)
        inflect.plural(/index$/, "indexes")         # for table name(s)
        inflect.plural(/VM and Instance$/, "VMs and Instances")
        inflect.plural(/VM Template and Image$/, "VM Templates and Images")
        inflect.singular(/Queue$/, "Queue")       # for Class name(s)
        inflect.plural(/Queue$/, "Queue")         # for Class name(s)
        inflect.singular(/queue$/, "queue")       # for table name(s)
        inflect.plural(/queue$/, "queue")         # for table name(s)
        inflect.singular(/Chassis$/, "Chassis")   # for Class name(s)
        inflect.plural(/Chassis$/, "Chassis")     # for Class name(s)
        inflect.singular(/chassis$/, "chassis")   # for table name(s)
        inflect.plural(/chassis$/, "chassis")     # for table name(s)
        inflect.singular(/quota$/, "quota")
        inflect.singular(/Quota$/, "Quota")
        inflect.plural(/quota$/, "quotas")
        inflect.irregular("container_quota", "container_quotas")

        inflect.acronym('ManageIQ')
      end
    end

    def self.load_plugin_inflections
      require_relative 'plugins'
      Vmdb::Plugins.load_inflections
    end
  end
end
