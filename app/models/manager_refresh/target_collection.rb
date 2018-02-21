module ManagerRefresh
  class TargetCollection
    attr_reader :targets

    delegate :<<, :to => :targets

    # @param manager [ManageIQ::Providers::BaseManager] manager owning the TargetCollection
    # @param manager_id [Integer] primary key of manager owning the TargetCollection
    # @param event [EmsEvent] EmsEvent associated with the TargetCollection
    # @param targets [Array<ManagerRefresh::Target, ApplicationRecord>] Array of ManagerRefresh::Target objects or
    #                ApplicationRecord objects
    def initialize(manager: nil, manager_id: nil, event: nil, targets: [])
      @manager    = manager
      @manager_id = manager_id
      @event      = event
      @targets    = targets
    end

    # @param association [Symbol] An existing association on Manager, that lists objects represented by a Target, naming
    #                             should be the same of association of a counterpart InventoryCollection object
    # @param manager_ref [Hash] A Hash that can be used to find_by on a given association and returning a unique object.
    #                           The keys should be the same as the keys of the counterpart InventoryObject
    # @param manager [ManageIQ::Providers::BaseManager] The Manager owning the Target
    # @param manager_id [Integer] A primary key of the Manager owning the Target
    # @param event_id [Integer] A primary key of the EmsEvent associated with the Target
    # @param options [Hash] A free form options hash
    def add_target(association:, manager_ref:, manager: nil, manager_id: nil, event_id: nil, options: {})
      self << ManagerRefresh::Target.new(:association => association,
                                         :manager_ref => manager_ref,
                                         :manager     => manager || @manager,
                                         :manager_id  => manager_id || @manager_id || @manager.try(:id),
                                         :event_id    => event_id || @event.try(:id),
                                         :options     => options)
    end

    # @return [String] A String containing a summary
    def name
      "Collection of #{targets.size} targets"
    end

    # @return [String] A String containing an id of each target in the TargetCollection
    def id
      "Collection of targets with id: #{targets.collect(&:name)}"
    end

    # Returns targets in a format:
    #   {
    #     :vms => {:ems_ref => Set.new(["vm_ref_1", "vm_ref2"])},
    #     :network_ports => {:ems_ref => Set.new(["network_port_1", "network_port2"])
    #   }
    #
    # Then we can quickly access all objects affected by:
    #   NetworkPort.where(target_collection.manager_refs_by_association[:network_ports].to_a) =>
    #     return AR objects with ems_refs ["network_port_1", "network_port2"]
    # And we can get a list of ids for the API query by:
    #   target_collection.manager_refs_by_association[:network_ports][:ems_ref].to_a =>
    #     ["network_port_1", "network_port2"]
    #
    # Only targets of a type ManagerRefresh::Target are processed, any other targets present should be converted to
    # ManagerRefresh::Target, e.g. in the Inventory::Collector code.
    def manager_refs_by_association
      @manager_refs_by_association ||= targets.select { |x| x.kind_of?(ManagerRefresh::Target) }.each_with_object({}) do |x, obj|
        if obj[x.association].blank?
          obj[x.association] = x.manager_ref.each_with_object({}) { |(key, value), hash| hash[key] = Set.new([value]) }
        else
          obj[x.association].each do |key, value|
            value << x.manager_ref[key]
          end
        end
      end
    end

    # Resets the cached @manager_refs_by_association to enforce reload when calling :manager_refs_by_association method
    def manager_refs_by_association_reset
      @manager_refs_by_association = nil
    end
  end
end
