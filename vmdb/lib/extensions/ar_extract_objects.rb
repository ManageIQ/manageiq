module ActiveRecord
  class Base
    def self.extract_objects(*objects)
      is_array = objects.length > 1 || objects.first.kind_of?(Array)
      objects = objects.flatten
      ret = objects.first.kind_of?(Integer) ? self.find_all_by_id(objects) : objects
      return is_array ? ret : ret.first
    end

    def self.extract_ids(*objects)
      is_array = objects.length > 1 || objects.first.kind_of?(Array)
      objects = objects.flatten
      ret = objects.first.kind_of?(self) ? objects.collect { |o| o.id } : objects
      return is_array ? ret : ret.first
    end
  end
end
