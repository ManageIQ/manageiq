module ManagerRefresh::SaveCollection
  module Saver
    class ConcurrentSafe < ManagerRefresh::SaveCollection::Saver::Base
      # TODO(lsmola) this strategy does not make much sense, it's better to use concurent_safe_batch and make batch size
      # configurable
      private

      # Updates the passed record with hash data and stores primary key value into inventory_object.
      #
      # @param record [ApplicationRecord] record we want to update in DB
      # @param hash [Hash] data we want to update the record with
      # @param inventory_object [ManagerRefresh::InventoryObject] InventoryObject instance where we will store primary
      #        key value
      def update_record!(record, hash, inventory_object)
        assign_attributes_for_update!(hash, time_now)
        record.assign_attributes(hash.except(:id))

        if !inventory_object.inventory_collection.check_changed? || record.changed?
          update_query = inventory_object.inventory_collection.model_class.where(:id => record.id)
          if hash[:remote_data_timestamp]
            timestamp_field = inventory_collection.model_class.arel_table[:remote_data_timestamp]
            update_query    = update_query.where(timestamp_field.lt(hash[:remote_data_timestamp]))
          end

          update_query.update_all(hash)
          inventory_collection.store_updated_records(record)
        end

        inventory_object.id = record.id
      end

      # Creates a new record in the DB using the passed hash data
      #
      # @param hash [Hash] hash with data we want to persist to DB
      # @param inventory_object [ManagerRefresh::InventoryObject] InventoryObject instance where we will store primary
      #        key value
      def create_record!(hash, inventory_object)
        all_attribute_keys = hash.keys
        data               = inventory_collection.model_class.new(hash).attributes.symbolize_keys

        # TODO(lsmola) abstract common behavior into base class
        all_attribute_keys << :type if supports_sti?
        all_attribute_keys << :created_at if supports_created_at?
        all_attribute_keys << :updated_at if supports_updated_at?
        all_attribute_keys << :created_on if supports_created_on?
        all_attribute_keys << :updated_on if supports_updated_on?
        hash_for_creation = if inventory_collection.use_ar_object?
                              record = inventory_collection.model_class.new(data)
                              values_for_database!(all_attribute_keys,
                                                   record.attributes.symbolize_keys)
                            elsif serializable_keys?
                              values_for_database!(all_attribute_keys,
                                                   data)
                            else
                              data
                            end

        assign_attributes_for_create!(hash_for_creation, time_now)

        result_id = ActiveRecord::Base.connection.execute(
          build_insert_query(all_attribute_keys, [hash_for_creation])
        )

        inventory_object.id = result_id.to_a.try(:first).try(:[], "id")
        inventory_collection.store_created_records(inventory_object)
      end
    end
  end
end
