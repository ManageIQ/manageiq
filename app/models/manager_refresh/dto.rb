module ManagerRefresh
  class Dto
    attr_reader :dto_collection, :data, :object

    delegate :manager_ref, :to => :dto_collection

    def initialize(dto_collection, data)
      @dto_collection           = dto_collection
      @data                     = data
      @object                   = nil
      @allowed_attributes_index = nil
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

    def attributes(dto_collection_scope = nil)
      # We should explicitly pass a scope, since the dto can be mapped to more DtoCollections with different blacklist
      # and whitelist. The generic code always passes a scope.
      dto_collection_scope ||= dto_collection

      # First transform the values
      data.each do |key, value|
        if !allowed?(dto_collection_scope, key)
          next
        elsif loadable?(value)
          data[key] = value.load
        elsif value.kind_of?(Array) && value.any? { |x| loadable?(x) }
          data[key] = value.compact.map(&:load).compact
        else
          next
        end
      end

      # Then return a new hash containing only the values according to the whitelist and the blacklist
      data.select { |key, _value| allowed?(dto_collection_scope, key) }
    end

    def to_s
      "Dto:('#{manager_uuid}', #{dto_collection})"
    end

    def inspect
      to_s
    end

    private

    attr_writer :object

    def allowed?(dto_collection_scope, key)
      # TODO(lsmola) can we make this O(1)? This check will be performed for each record in the DB

      return false if dto_collection_scope.attributes_blacklist.present? && dto_collection_scope.attributes_blacklist.include?(key)
      return false if dto_collection_scope.attributes_whitelist.present? && !dto_collection_scope.attributes_whitelist.include?(key)
      true
    end

    def loadable?(value)
      value.kind_of?(::ManagerRefresh::DtoLazy) || value.kind_of?(::ManagerRefresh::Dto)
    end
  end
end
