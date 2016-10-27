module ManagerRefresh
  class DtoLazy
    include Vmdb::Logging

    attr_reader :ems_ref, :dto_collection, :path, :default

    def initialize(dto_collection, ems_ref, path: nil, default: nil)
      @ems_ref        = ems_ref
      @dto_collection = dto_collection
      @path           = path
      @default        = default
    end

    def to_s
      ems_ref
    end

    def inspect
      "DtoLazy:('#{self}', #{dto_collection})"
    end

    def load
      path ? load_object_with_path : load_object
    end

    def dependency?
      !path || dto_collection.dependency_attributes.keys.include?(path.first)
    end

    private

    def load_object_with_path
      (dto_collection.find(to_s).try(:data) || {}).fetch_path(*path) || default
    end

    def load_object
      dto_collection_member = dto_collection.find(to_s)
      dto_collection_member.respond_to?(:object) ? dto_collection_member.object : dto_collection_member
    end
  end
end
