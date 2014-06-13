module MiqHostProvision::Tagging
  def apply_tags(host)
    log_header = "MIQ(#{self.class.name}#apply_tags)"

    self.tags do |tag, cat|
      $log.info("#{log_header} Tagging [#{host.name}], Category: [#{cat}], Tag: #{tag}")
      Classification.classify(host, cat.to_s, tag)
    end
  end
end
