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

  def object
    data[:_object]
  end

  def attributes
    data.transform_values! do |value|
      if value.is_a? ::DtoLazy
        value.load
      else
        value
      end
    end
  end
end
