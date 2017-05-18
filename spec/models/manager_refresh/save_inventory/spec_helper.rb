module SpecHelper
  def assert_all_records_match_hashes(model_classes, *expected_match)
    # Helper for matching attributes of the model's records to an Array of hashes
    model_classes = model_classes.kind_of?(Array) ? model_classes : [model_classes]
    attributes    = expected_match.first.keys
    model_classes.each { |m| expect(sliced_records_of(m, attributes)).to(match_array(expected_match)) }
  end

  def sliced_records_of(model_class, attributes)
    model_class.to_a.map { |x| x.slice(*attributes).symbolize_keys }
  end

  def add_data_to_inventory_collection(inventory_collection, *args)
    # Creates InventoryObject object from each arg and adds it into the InventoryCollection
    args.each { |data| inventory_collection << inventory_collection.new_inventory_object(data) }
  end
end
