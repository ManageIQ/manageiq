module DDF
  def self.traverse(schema, &block)
    recurse = ->(item) { traverse(item, &block) }

    if schema.kind_of?(Array)
      schema.each(&recurse)
    elsif schema.kind_of?(Hash)
      yield(schema)
      schema.try(:[], :fields).try(:each, &recurse)
    end
  end

  def self.extract_attributes(schema, attribute)
    arr = []
    traverse(schema) do |item|
      arr.push(item[attribute])
    end

    arr.compact.uniq
  end

  def self.find_field(schema, id)
    traverse(schema) do |item|
      return item if item[:id] == id
    end
    nil
  end
end
