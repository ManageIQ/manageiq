module ManagerRefresh
  class Dto
    attr_reader :dto_collection, :data, :object

    delegate :manager_ref, :to => :dto_collection

    def initialize(dto_collection, data)
      @dto_collection = dto_collection
      @data           = data
      @built_data     = nil
    end

    def manager_uuid
      manager_ref.map { |attribute| data[attribute].try(:id) || data[attribute].to_s }.join("__")
    end

    def id
      object.id
    end

    def [](key)
      data[key]
    end

    def []=(key, value)
      data[key] = value
    end

    def load
      object
    end

    def build_object(built_object)
      self.object = built_object
    end

    def save
      ret = object.save
      object.send(:clear_association_cache)
      ret
    end

    def attributes
      unless dto_collection.attributes_blacklist.blank?
        data.delete_if { |key, _value| dto_collection.attributes_blacklist.include?(key) }
      end

      data.transform_values! do |value|
        if loadable?(value)
          value.load
        elsif value.kind_of?(Array) && value.any? { |x| loadable?(x) }
          value.compact.map(&:load).compact
        else
          value
        end
      end
    end

    def to_s
      "Dto:('#{manager_uuid}', #{dto_collection})"
    end

    def inspect
      to_s
    end

    private

    def object=(built_object)
      @object = built_object
    end

    def loadable?(value)
      value.kind_of?(::ManagerRefresh::DtoLazy) || value.kind_of?(::ManagerRefresh::Dto)
    end
  end
end
