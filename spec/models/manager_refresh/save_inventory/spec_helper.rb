module SpecHelper
  def assert_all_records_match_hashes(model_classes, *expected_match)
    # Helper for matching attributes of the model's records to an Array of hashes
    model_classes = model_classes.kind_of?(Array) ? model_classes : [model_classes]
    attributes    = expected_match.first.keys
    model_classes.each { |m| expect(m.to_a.map { |x| x.slice(*attributes) }).to(match_array(expected_match)) }
  end

  def add_data_to_dto_collection(dto_collection, *args)
    # Creates Dto object from each arg and adds it into the DtoCollection
    args.each { |data| dto_collection << dto_collection.new_dto(data) }
  end
end
