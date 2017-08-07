module SecurityGroup::Operations
  extend ActiveSupport::Concern

  def update_security_group(options = {})
    raw_update_security_group(options)
  end

  def raw_update_security_group(_options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def delete_security_group
    raw_delete_security_group
  end

  def raw_delete_security_group
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
