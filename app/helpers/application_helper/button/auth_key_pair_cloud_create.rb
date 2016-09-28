class ApplicationHelper::Button::AuthKeyPairCloudCreate < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if disabled?
      self[:title] = _("No cloud providers support key pair import or creation.")
    end
  end

  def disabled?
    # check that at least one EMS the user has access to supports
    # creation or import of key pairs.
    Rbac.filtered(ManageIQ::Providers::CloudManager.all).each do |ems|
      if ems.class::AuthKeyPair.is_available?(:create_key_pair, ems)
        return false
      end
    end
    return true
  end
end
