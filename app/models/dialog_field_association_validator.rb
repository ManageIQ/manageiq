class DialogFieldAssociationValidator
  def circular_references(associations)
    return false if associations.empty?
    association_path_list = initial_paths(associations)
    association_path_list.each do |path|
      fieldname_being_triggered = path.last
      next if associations[fieldname_being_triggered].blank?
      circular_references = walk_value_path(fieldname_being_triggered, associations, path)
      return circular_references if circular_references.present?
    end
    false
  end

  private

  def initial_paths(associations)
    associations.flat_map { |key, values| values.map { |value| [key, value] } }
  end

  def walk_value_path(fieldname_being_triggered, associations, path)
    while associations[fieldname_being_triggered].present?
      return [fieldname_being_triggered, associations[fieldname_being_triggered].first] if path.include?(associations[fieldname_being_triggered].first)
      path << associations[fieldname_being_triggered]
      path.flatten!
      fieldname_being_triggered = path.last
    end
  end
end
