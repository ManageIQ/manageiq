class DtoLazy
  attr_reader :ems_ref, :dto_collection

  def initialize(dto_collection, ems_ref)
    @ems_ref        = ems_ref
    @dto_collection = dto_collection
  end

  def to_s
    ems_ref
  end

  def load
    dto_collection.find(to_s).try!(:object)
  end
end
