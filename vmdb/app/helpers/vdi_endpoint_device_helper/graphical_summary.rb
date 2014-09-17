module VdiEndpointDeviceHelper::GraphicalSummary

  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{vdi_sessions}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

end
