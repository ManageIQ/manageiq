module ManagerRefresh
  class InventoryCollection
    module Index
      module Type
        class Skeletal < ManagerRefresh::InventoryCollection::Index::Type::Base
          # (see ManagerRefresh::InventoryCollection::Index::Type::Base#initialize)
          # @param primary_index [ManagerRefresh::InventoryCollection::Index::Type::Data] Data index of primary_index
          def initialize(inventory_collection, index_name, attribute_names, primary_index)
            super

            @primary_index = primary_index
          end

          delegate :default_values,
                   :new_inventory_object,
                   :named_ref,
                   :to => :inventory_collection

          delegate :blank?,
                   :each,
                   :each_value,
                   :to => :index

          # Find value based on index_value
          #
          # @param index_value [String] a index_value of the InventoryObject we search for
          # @return [InventoryObject|nil] Returns found value or nil
          def find(index_value)
            index[index_value]
          end

          # Deletes and returns the value on the index_value
          #
          # @param index_value [String] a index_value of the InventoryObject we search for
          # @return [InventoryObject|nil] Returns found value or nil
          def delete(index_value)
            index.delete(index_value)
          end

          # Takes value from primary_index and inserts it to skeletal index
          #
          # @param index_value [String] a index_value of the InventoryObject we search for
          # @return [InventoryObject|nil] Returns found value or nil
          def skeletonize_primary_index(index_value)
            inventory_object = primary_index.delete(index_value)
            return unless inventory_object
            fill_versions!(inventory_object.data)

            index[index_value] = inventory_object
          end

          # Builds index record with skeletal InventoryObject and returns it. Or it returns existing InventoryObject
          # that is found in primary_index or skeletal_primary_index.
          #
          # @param attributes [Hash] Skeletal data of the index, must contain unique index keys and everything else
          #        needed for creating the record in the Database
          # @return [InventoryObject] Returns built InventoryObject or existing InventoryObject with new attributes
          #         assigned
          def build(attributes)
            attributes = {}.merge!(default_values).merge!(attributes)
            fill_versions!(attributes)

            # If the primary index is already filled, we don't want populate skeletal index
            uuid = ::ManagerRefresh::InventoryCollection::Reference.build_stringified_reference(attributes, named_ref)
            if (inventory_object = primary_index.find(uuid))
              return inventory_object.assign_attributes(attributes)
            end

            # Return if skeletal index already exists
            if (inventory_object = index[uuid])
              return inventory_object.assign_attributes(attributes)
            end

            # We want to populate a new skeletal index
            inventory_object                     = new_inventory_object(attributes)
            index[inventory_object.manager_uuid] = inventory_object
          end

          private

          attr_reader :primary_index

          # Add versions columns into the passed attributes
          #
          # @param attributes [Hash] Attributes we want to extend with version related attributes
          def fill_versions!(attributes)
            if inventory_collection.supports_resource_timestamps_max? && attributes[:resource_timestamp]
              fill_specific_version_attr(:resource_timestamps, :resource_timestamp, attributes)
            elsif inventory_collection.supports_resource_versions_max? && attributes[:resource_version]
              fill_specific_version_attr(:resource_versions, :resource_version, attributes)
            end
          end

          # Add specific versions columns into the passed attributes
          #
          # @param partial_row_version_attr [Symbol] Attr name for partial rows, allowed values are
          #        [:resource_timestamps, :resource_versions]
          # @param full_row_version_attr [Symbol] Attr name for full rows, allowed values are
          #        [:resource_timestamp, :resource_version]
          # @param attributes [Hash] Attributes we want to extend with version related attributes
          def fill_specific_version_attr(partial_row_version_attr, full_row_version_attr, attributes)
            # We have to symbolize, since serializing persistor makes these strings
            (attributes[partial_row_version_attr] ||= {}).symbolize_keys!

            (attributes.keys - inventory_collection.base_columns).each do |key|
              attributes[partial_row_version_attr][key] ||= attributes[full_row_version_attr]
            end
          end
        end
      end
    end
  end
end
