module ManagerRefresh
  class Dto
    attr_reader :dto_collection, :data

    def initialize(dto_collection, data)
      @dto_collection = dto_collection
      # TODO filter the data according to attributes and throw exception using non recognized attr
      @data           = data
    end

    def manager_uuid
      manager_ref.map { |attribute| data[attribute].to_s }.join("__")
    end

    def manager_ref
      dto_collection.manager_ref
    end

    def id
      data[:id]
    end

    def [](key)
      data[key]
    end

    def []=(key, value)
      data[key] = value
    end

    def object
      data[:_object]
    end

    def attributes
      data.transform_values! do |value|
        if value.is_a? ::ManagerRefresh::DtoLazy
          value.load
        elsif value.kind_of?(Array) && value.any? { |x| x.is_a? ::ManagerRefresh::DtoLazy }
          value.compact.map { |x| x.load }.compact
        else
          value
        end
      end
    end

    def to_s
      "Dto:('#{id}', #{dto_collection})"
    end

    def inspect
      to_s
    end
  end
end
