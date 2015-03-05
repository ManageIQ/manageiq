module ContainerGroupHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{namespace }
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{}
   # items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_namespace
    {:label => "Namespace", :value => @record.namespace}
  end
end
