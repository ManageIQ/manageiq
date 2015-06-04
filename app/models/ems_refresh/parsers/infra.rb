module EmsRefresh::Parsers
  class Infra
    def parse_security_group(sg)
      uid = sg.id

      new_result = {
        :type        => self.class.security_group_type,
        :ems_ref     => uid,
        :name        => sg.name,
        :description => sg.description.truncate(255)
      }

      return uid, new_result
    end
  end
end
