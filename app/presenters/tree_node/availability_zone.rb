module TreeNode
  class AvailabilityZone < Node
    set_attribute(:image, '100/availability_zone.png')
    set_attribute(:tooltip) { |object| _("Availability Zone: %{name}") % {:name => object.name} }
  end
end
