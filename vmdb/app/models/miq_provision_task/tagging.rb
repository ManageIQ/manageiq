module MiqProvisionTask::Tagging
  def apply_tags(inv_obj)
    tags do |tag, cat|
      $log.info("#{self.class.name}##{__method__} Tagging [#{inv_obj.name}], Category: [#{cat}], Tag: #{tag}")
      Classification.classify(inv_obj, cat.to_s, tag)
    end
  end
end
