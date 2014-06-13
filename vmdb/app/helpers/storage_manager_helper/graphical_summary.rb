module StorageManagerHelper::GraphicalSummary
  #
  # Groups
  #

  def graphical_group_properties
    items = %w{created_at}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_created_at
    {:label => "Created At", :value => @record_created_at}
  end
end
