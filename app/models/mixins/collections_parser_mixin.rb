module CollectionsParserMixin
  def process_collection(collection, key, &block)
    @data[key] ||= []
    collection.each { |item| process_collection_item(item, key, &block) }
  end

  def process_collection_item(item, key)
    @data[key] ||= []

    new_result = yield(item)

    @data[key] << new_result
    new_result
  end
end
