module ContainerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{image}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{}
   # items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_image
    {:label => "image", :value => @record.image}
  end
end
