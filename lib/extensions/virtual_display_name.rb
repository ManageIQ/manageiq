module VirtualDisplayName

  # define an attribute to contain display text, in order of preference:
  # description, if and when available
  # title/name in case description is not available or does not exist
  # default to <record id> in cases where no other attribute has been provided by user
  def virtual_display_name
    return label                      if respond_to?("label")
    return description                if respond_to?("description") && description.present?
    return ext_management_system.name if respond_to?("ems_id")
    return title                      if respond_to?("title")
    return name                       if respond_to?("name")
    "<Record ID #{record.id}>"
  end
end
