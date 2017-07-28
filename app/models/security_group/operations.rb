module SecurityGroup::Operations
  extend ActiveSupport::Concern

  def update_security_group(options = {})
    raw_update
  end

  def raw_update(options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def delete_security_group
    raw_delete
  end

  def raw_delete
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
