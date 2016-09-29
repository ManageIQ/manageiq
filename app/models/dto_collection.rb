class DtoCollection
  attr_accessor :saved, :data, :data_index,
                :dependencies, :manager_ref, :attributes

  def initialize(model_class, dependencies: nil, manager_ref: nil, attributes: nil)
    @model_class  = model_class
    @dependencies = dependencies || []
    @manager_ref  = manager_ref  || [:ems_ref]
    @attributes   = attributes   || []
    @data         = []
    @data_index   = {}
    @saved        = false
  end

  def saved?
    saved
  end

  def saveable?(hashes)
    dependencies.all? do |dep|
      hashes[dep].saved?
    end
  end

  def <<(dto)
    data_index[dto.manager_uuid] = dto
    data << dto
  end

  def find(manager_uuid)
    data_index[manager_uuid]
  end

  def lazy_find(manager_uuid)
    ::DtoLazy.new(self, manager_uuid)
  end

  def new_dto(hash)
    ::Dto.new(self, hash)
  end

  def each(*args, &block)
    data.each(*args, &block)
  end
end
