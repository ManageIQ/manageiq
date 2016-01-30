class ManageIQ::Providers::InfraManager::RefreshParser
  private

  def parse_key_pair(kp)
    name = uid = kp.name

    new_result = {
      :type        => self.class.key_pair_type,
      :name        => name,
      :fingerprint => kp.fingerprint
    }

    return uid, new_result
  end

  def parse_security_group(sg)
    uid = sg.id

    new_result = {
      :type        => self.class.security_group_type,
      :ems_ref     => uid,
      :name        => sg.name,
      :description => sg.description.try(:truncate, 255)
    }

    return uid, new_result
  end
end
