module MiqHostProvision::Tagging
  def apply_tags(host)
    self.tags do |tag, cat|
      _log.info("Tagging [#{host.name}], Category: [#{cat}], Tag: #{tag}")
      Classification.classify(host, cat.to_s, tag)
    end
  end
end
