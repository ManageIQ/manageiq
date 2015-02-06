module MiqAeMethodService
  class MiqAeServiceVmVmware < MiqAeServiceVmInfra
    require_relative "mixins/miq_ae_service_ems_operations_mixin"
    include MiqAeServiceEmsOperationsMixin

    def set_number_of_cpus(count, options = {})
      sync_or_async_ems_operation(options[:sync], "set_number_of_cpus", [count])
    end

    def set_memory(size_mb, options = {})
      sync_or_async_ems_operation(options[:sync], "set_memory", [size_mb])
    end

    def add_disk(disk_name, disk_size_mb, options = {})
      sync_or_async_ems_operation(options[:sync], "add_disk", [disk_name, disk_size_mb])
    end
  end
end
