module ManagerRefresh
  class InventoryCollection
    class Scanner
      class << self
        # Scanning inventory_collections for dependencies and references, storing the results in the inventory_collections
        # themselves. Dependencies are needed for building a graph, references are needed for effective DB querying, where
        # we can load all referenced objects of some InventoryCollection by one DB query.
        #
        # @param inventory_collections [Array] Array fo
        def scan!(inventory_collections)
          indexed_inventory_collections = inventory_collections.index_by(&:name)

          inventory_collections.each do |inventory_collection|
            new(inventory_collection, indexed_inventory_collections).scan!
          end

          inventory_collections.each do |inventory_collection|
            inventory_collection.dependencies.each do |dependency|
              dependency.dependees << inventory_collection
            end
          end
        end
      end

      attr_reader :inventory_collection, :indexed_inventory_collections

      # Boolean helpers the scanner uses from the :inventory_collection
      delegate :inventory_object_lazy?,
               :inventory_object?,
               :targeted?,
               :to => :inventory_collection

      # Methods the scanner uses from the :inventory_collection
      delegate :data,
               :find_or_build,
               :manager_ref,
               :saver_strategy,
               :to => :inventory_collection

      # The data scanner modifies inside of the :inventory_collection
      delegate :attribute_references,
               :data_collection_finalized=,
               :dependency_attributes,
               :targeted_scope,
               :parent_inventory_collections,
               :parent_inventory_collections=,
               :references,
               :transitive_dependency_attributes,
               :to => :inventory_collection

      def initialize(inventory_collection, indexed_inventory_collections)
        @inventory_collection          = inventory_collection
        @indexed_inventory_collections = indexed_inventory_collections
      end

      def scan!
        # Scan InventoryCollection InventoryObjects and store the results inside of the InventoryCollection
        data.each do |inventory_object|
          scan_inventory_object!(inventory_object)

          if targeted? && parent_inventory_collections.blank?
            # We want to track what manager_uuids we should query from a db, for the targeted refresh
            targeted_scope[inventory_object.manager_uuid] = inventory_object.reference
          end
        end

        # Transform :parent_inventory_collections symbols to InventoryCollection objects
        if parent_inventory_collections.present?
          self.parent_inventory_collections = parent_inventory_collections.map do |inventory_collection_index|
            ic = indexed_inventory_collections[inventory_collection_index]
            if ic.nil?
              raise "Can't find InventoryCollection #{inventory_collection_index} from #{inventory_collection}" if targeted?
            else
              # Add parent_inventory_collection as a dependency, so e.g. disconnect is done in a right order
              (dependency_attributes[:__parent_inventory_collections] ||= Set.new) << ic
              ic
            end
          end.compact
        end

        # Mark InventoryCollection as finalized aka. scanned
        self.data_collection_finalized = true
      end

      private

      def scan_inventory_object!(inventory_object)
        inventory_object.data.each do |key, value|
          if value.kind_of?(Array)
            value.each { |val| scan_inventory_object_attribute!(key, val) }
          else
            scan_inventory_object_attribute!(key, value)
          end
        end
      end

      def scan_inventory_object_attribute!(key, value)
        return if !inventory_object_lazy?(value) && !inventory_object?(value)
        value_inventory_collection = value.inventory_collection

        # Storing attributes and their dependencies
        (dependency_attributes[key] ||= Set.new) << value_inventory_collection if value.dependency?

        # Storing a reference in the target inventory_collection, then each IC knows about all the references and can
        # e.g. load all the referenced uuids from a DB
        value_inventory_collection.add_reference(value.reference, :key => value.try(:key))

        if inventory_object_lazy?(value)
          # Storing if attribute is a transitive dependency, so a lazy_find :key results in dependency
          transitive_dependency_attributes << key if value.transitive_dependency?
        end
      end
    end
  end
end
