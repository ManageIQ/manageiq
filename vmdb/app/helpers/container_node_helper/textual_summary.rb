module ContainerNodeHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{name}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{}
    # items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @record.name}
  end
end
