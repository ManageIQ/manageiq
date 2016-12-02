module ManagerRefresh
  class DtoLazy
    include Vmdb::Logging

    attr_reader :ems_ref, :dto_collection, :key, :default

    def initialize(dto_collection, ems_ref, key: nil, default: nil)
      @ems_ref        = ems_ref
      @dto_collection = dto_collection
      @key            = key
      @default        = default
    end

    def to_s
      ems_ref
    end

    def inspect
      suffix = ""
      suffix += ", key: #{key}" if key.present?
      "DtoLazy:('#{self}', #{dto_collection})#{suffix}"
    end

    def load
      key ? load_object_with_key : load_object
    end

    def dependency?
      # If key is not set, DtoLazy is a dependency, cause it points to the record itself. Otherwise DtoLazy is a
      # dependency only if it points to an attribute which is a dependency or a relation.
      !!(!key || transitive_dependency?)
    end

    def transitive_dependency?
      !!(key && (dto_collection.dependency_attributes.keys.include?(key) ||
        dto_collection.model_class.reflect_on_association(key)))
    end

    private

    def load_object_with_key
      # TODO(lsmola) Log error if we are accessing path that is present in blacklist or not present in whitelist
      (dto_collection.find(to_s).try(:data) || {})[key] || default
    end

    def load_object
      dto_collection_member = dto_collection.find(to_s)
      dto_collection_member.respond_to?(:object) ? dto_collection_member.object : dto_collection_member
    end
  end
end
