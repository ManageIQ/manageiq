module ManageIQ::Providers
  module Openstack
    module RefreshParserCommon
      module HelperMethods
        def process_collection(collection, key, &block)
          @data[key] ||= []
          return if @options && @options[:inventory_ignore] && @options[:inventory_ignore].include?(key)
          collection.each { |item| process_collection_item(item, key, &block) }
        end

        def process_collection_item(item, key)
          @data[key] ||= []

          uid, new_result = yield(item)

          @data[key] << new_result
          @data_index.store_path(key, uid, new_result)
          new_result
        end
      end
    end
  end
end
