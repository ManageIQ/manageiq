module ActiveRecord
  class Base
    def self.extract_objects(*objects)
      is_array = objects.length > 1 || objects.first.kind_of?(Array)
      objects = objects.flatten
      ret = objects.first.kind_of?(Integer) ? where(:id => objects) : objects
      is_array ? ret : ret.first
    end

    def self.extract_ids(*objects)
      is_array = objects.length > 1 || objects.first.kind_of?(Array)
      objects = objects.flatten
      ret = objects.first.kind_of?(self) ? objects.collect(&:id) : objects
      is_array ? ret : ret.first
    end
  end
end
