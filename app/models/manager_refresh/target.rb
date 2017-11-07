module ManagerRefresh
  class Target
    attr_reader :association, :manager_ref, :event_id, :options, :payload_id

    # @param association [Symbol] An existing association on Manager, that lists objects represented by a Target, naming
    #                             should be the same of association of a counterpart InventoryCollection object
    # @param manager_ref [Hash] A Hash that can be used to find_by on a given association and returning a unique object.
    #                           The keys should be the same as the keys of the counterpart InventoryObject
    # @param manager [ManageIQ::Providers::BaseManager] The Manager owning the Target
    # @param manager_id [Integer] A primary key of the Manager owning the Target
    # @param event_id [Integer] A primary key of the EmsEvent associated with the Target
    # @param options [Hash] A free form options hash
    def initialize(association:, manager_ref:, manager: nil, manager_id: nil, event_id: nil, payload_id: nil, options: {})
      raise "Provide either :manager or :manager_id argument" if manager.nil? && manager_id.nil?

      @manager     = manager
      @manager_id  = manager_id
      @association = association
      @manager_ref = manager_ref
      @event_id    = event_id
      @payload_id  = payload_id
      @options     = options
    end

    # A Rails recommended interface for deserializing an object
    def self.load(*args)
      new(*args)
    end

    # A Rails recommended interface for serializing an object
    def self.dump(obj)
      obj.dump
    end

    # Returns a serialized ManagerRefresh::Target object. This can be used to initialize a new object, then the object
    # target acts the same as the object ManagerRefresh::Target.new(target.serialize)
    def dump
      {
        :manager_id  => manager_id,
        :association => association,
        :manager_ref => manager_ref,
        :payload_id  => payload_id,
        :event_id    => event_id,
        :options     => options
      }
    end

    alias id dump
    alias name manager_ref

    def payload=(data)
      payload_blob.try(:destroy)
      @payload_id = data ? BinaryBlob.create!(:binary => data).id : nil
    end

    def payload
      payload_blob.try(:binary)
    end

    # @return [ManageIQ::Providers::BaseManager] The Manager owning the Target
    def manager
      @manager || ManageIQ::Providers::BaseManager.find(@manager_id)
    end

    # @return [Integer] A primary key of the Manager owning the Target
    def manager_id
      @manager_id || manager.try(:id)
    end

    # Loads ManagerRefresh::Target ApplicationRecord representation from our DB, this requires that ManagerRefresh::Target
    # has been refreshed, otherwise the AR object can be missing.
    # @return [ApplicationRecord] A ManagerRefresh::Target loaded from the database as AR object
    def load_from_db
      manager.public_send(association).find_by(manager_ref)
    end

    def payload_blob
      BinaryBlob.find_by(:id => payload_id) if payload_id
    end
  end
end
