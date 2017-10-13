module ContentImporter
  def self.import_from_hash(set_class, set_element_class, set_class_attributes, options = {})
    status = {:class => name, :description => set_class_attributes["description"], :children => []}
    profiles = set_class_attributes.delete(set_element_class.name) do |_k|
      raise _("No %{elements} for %{type} Profile == %{profile}") % {:type => set_element_class.display_name, :elements => set_element_class.display_name.pluralize, :profile => set_class_attributes.inspect}
    end

    set_element_array = []
    profiles.each do |p|
      set_element, s = set_element_class.import_from_hash(p, options)
      status[:children].push(s)
      set_element_array.push(set_element)
    end

    set_instance = set_class.find_by(:guid => set_class_attributes["guid"])
    msg_pfx = "Importing #{set_element_class.display_name} Profile: guid=[#{set_class_attributes["guid"]}] description=[#{set_class_attributes["description"]}]"
    if set_instance.nil?
      set_instance = set_class.new(set_class_attributes)
      status[:status] = :add
    else
      status[:old_description] = set_instance.description
      set_instance.attributes = set_class_attributes
      status[:status] = :update
    end

    unless set_instance.valid?
      status[:status]   = :conflict
      status[:messages] = set_instance.errors.full_messages
    end

    set_instance["mode"] ||= "control" # Default "mode" value to true to suprofilesort older export decks that don't have a value set.

    msg = "#{msg_pfx}, Status: #{status[:status]}"
    msg += ", Messages: #{status[:messages].join(",")}" if status[:messages]
    if options[:preview] == true
      set_element_class.logger.info("[PREVIEW] #{msg}")
    else
      set_element_class.logger.info(msg)
      set_instance.save!
      set_element_array.each { |p| set_instance.add_member(p) }
    end

    return set_instance, status
  end
end
