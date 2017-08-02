module ManagerRefresh::SaveCollection
  module Saver
    class ConcurrentSafe < ManagerRefresh::SaveCollection::Saver::Base
      private

      def update_record!(record, hash, inventory_object)
        assign_attributes_for_update!(hash, time_now)
        record.assign_attributes(hash.except(:id, :type))

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

      def create_record!(hash, inventory_object)
        all_attribute_keys = hash.keys
        hash               = inventory_collection.model_class.new(hash).attributes.symbolize_keys
        assign_attributes_for_create!(hash, time_now)

        result_id = ActiveRecord::Base.connection.insert_sql(
          build_insert_query(all_attribute_keys, [hash])
        )
        inventory_object.id = result_id
        inventory_collection.store_created_records(inventory_object)
      end
    end
  end
end
