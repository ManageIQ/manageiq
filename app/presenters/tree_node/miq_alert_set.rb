module TreeNode
  class MiqAlertSet < Node
    set_attribute(:title, &:description)
    set_attribute(:image, '100/miq_alert_profile.png')
  end
end
