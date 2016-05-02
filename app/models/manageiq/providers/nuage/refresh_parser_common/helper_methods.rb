module ManageIQ::Providers
  module Nuage
    module RefreshParserCommon
      module HelperMethods
        def process_collection(collection, key)
          @data[key] ||= []

          collection.each do |item|
            uid, new_result = yield(item)
            next if uid.nil?

            @data[key] << new_result
            @data_index.store_path(key, uid, new_result)
          end
        end
      end
    end
  end
end
