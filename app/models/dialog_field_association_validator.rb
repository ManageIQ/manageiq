class DialogFieldAssociationValidator
  class DialogFieldAssociationCircularReferenceError < StandardError; end

  def circular_references?(associations)
    keys_list = associations.collect(&:keys).flatten
    values_list = associations.collect(&:values).flatten
    associations.each do |association|
      association.values.flatten.each do |responder|
        association.values.first.delete(responder) unless keys_list.include?(responder)
      end
    end
    associations.each do |association|
      associations.delete(association) unless values_list.include?(association.keys.first)
    end
    circular_keys = associations.collect(&:keys).flatten.to_set
    circular_values = associations.collect(&:values).flatten.to_set
    circular_keys == circular_values unless circular_keys.empty? && circular_values.empty?
  end
end
