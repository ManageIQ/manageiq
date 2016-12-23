class UniqueWithinRegionValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil?
    match_case = options.key?(:match_case) ? options[:match_case] : true
    field_matches =
      if match_case
        record.class.where(attribute => value)
      else
        record.class.where("LOWER(#{attribute}) = ?", value.downcase)
      end
    unless field_matches.in_region(record.region_id).where.not(:id => record.id).empty?
      record.errors.add(attribute, "is not unique within region #{record.region_id}")
    end
  end
end
