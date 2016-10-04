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
    dependencies.all? do |dep|
      dep.saved?
    end
  end

  def <<(dto)
    unless data_index[dto.manager_uuid]
      data_index[dto.manager_uuid] = dto
      data << dto

      actualize_dependencies(dto)
    end
  end

  def find(manager_uuid)
    raise "Trying to find #{manager_uuid} in a non saved DtoCollection #{self}" unless saved?
    data_index[manager_uuid]
  end

  def lazy_find(manager_uuid, path: nil)
    ::DtoLazy.new(self, manager_uuid, :path => path)
  end

  def new_dto(hash)
    ::Dto.new(self, hash)
  end

  def each(*args, &block)
    data.each(*args, &block)
  end

  def to_a
    data
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
      if value.is_a? ::DtoLazy
        dependencies << value.dto_collection
      elsif value.kind_of?(Array) && value.any? { |x| x.is_a? ::DtoLazy }
        dependencies << value.detect { |x| x.is_a? ::DtoLazy }.dto_collection
      end
    end
    dependencies.uniq!
  end
end
