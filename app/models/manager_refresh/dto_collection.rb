module ManagerRefresh
  class DtoCollection
    attr_accessor :saved, :data, :data_index, :dependencies,
                  :manager_ref, :attributes, :association, :parent

    attr_reader :model_class

    def initialize(model_class, manager_ref: nil, attributes: nil, association: nil, parent: nil)
      @model_class  = model_class
      @manager_ref  = manager_ref || [:ems_ref]
      @attributes   = attributes || []
      @association  = association || []
      @parent       = parent || []
      @dependencies = []
      @data         = []
      @data_index   = {}
      @saved        = false
    end

    def saved?
      saved
    end

    def saveable?
      dependencies.all?(&:saved?)
    end

    def <<(dto)
      unless data_index[dto.manager_uuid]
        data_index[dto.manager_uuid] = dto
        data << dto

        actualize_dependencies(dto)
      end
    end

    def object_index(object)
      manager_ref.map { |attribute| object.public_send(attribute).try(:id) || object.public_send(attribute).to_s }.join("__")
    end

    def find(manager_uuid)
      data_index[manager_uuid]
    end

    def lazy_find(manager_uuid, path: nil)
      ::ManagerRefresh::DtoLazy.new(self, manager_uuid, :path => path)
    end

    def new_dto(hash)
      ::ManagerRefresh::Dto.new(self, hash)
    end

    def each(*args, &block)
      data.each(*args, &block)
    end

    def to_a
      data
    end

    def size
      to_a.size
    end

    def to_hash
      data_index
    end

    def to_s
      "DtoCollection:<#{@model_class}>"
    end

    def inspect
      to_s
    end

    private

    def actualize_dependencies(dto)
      dto.data.values.each do |value|
        if value.kind_of? ::ManagerRefresh::DtoLazy
          dependencies << value.dto_collection
        elsif value.kind_of?(Array) && value.any? { |x| x.kind_of? ::ManagerRefresh::DtoLazy }
          dependencies << value.detect { |x| x.kind_of? ::ManagerRefresh::DtoLazy }.dto_collection
        end
      end
      dependencies.uniq!
    end
  end
end
