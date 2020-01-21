class UniqueWithinRegionValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil?
    match_case = options.key?(:match_case) ? options[:match_case] : true
    record_base_class = record.class.base_class
    matches =
      if match_case
        record_base_class.where(attribute => value)
      else
        record_base_class.where(record_base_class.arel_attribute(attribute).lower.eq(value.downcase))
      end
    matches = matches.where(options[:scope] => record.public_send(options[:scope])) if options.key?(:scope)
    unless matches.in_region(record.region_id).where.not(:id => record.id).empty?
      record.errors.add(attribute, "is not unique within region #{record.region_id}")
    end
  end
end
