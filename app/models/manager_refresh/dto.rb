module ManagerRefresh
  class Dto
    attr_reader :dto_collection, :data

    delegate :manager_ref, :to => :dto_collection

    def initialize(dto_collection, data)
      @dto_collection = dto_collection
      # TODO(lsmola) filter the data according to attributes and throw exception using non recognized attr
      @data           = data
    end

    def manager_uuid
      manager_ref.map { |attribute| data[attribute].try(:id) || data[attribute].to_s }.join("__")
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
        if value.kind_of? ::ManagerRefresh::DtoLazy
          value.load
        elsif value.kind_of?(Array) && value.any? { |x| x.kind_of? ::ManagerRefresh::DtoLazy }
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
  end
end
