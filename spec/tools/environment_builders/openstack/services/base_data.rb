module Openstack
  module Services
    class BaseData
      def indexed_collection_return(collection, index = nil)
        if index
          collection[index]
        else
          collection.values.flatten
        end
      end
    end
  end
end
