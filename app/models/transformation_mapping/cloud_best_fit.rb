class TransformationMapping
  class CloudBestFit
    attr_reader :source_vm, :destination_manager
    def initialize(source_vm, destination_manager)
      @source_vm = source_vm
      @destination_manager = destination_manager
    end

    def available_fit_flavors
      @available_fit_flavors ||= destination_manager.flavors.where(
        :cpus   => source_vm.cpu_total_cores..Float::INFINITY,
        :memory => (source_vm.hardware.memory_mb * 1.megabyte)..Float::INFINITY
      ).order(:cpus, :memory)
    end

    def best_fit_flavor
      available_fit_flavors.first
    end
  end
end
