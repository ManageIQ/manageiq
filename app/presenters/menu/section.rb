module Menu
  Section = Struct.new(:id, :name, :items, :placement, :before, :type, :href) do
    def initialize(an_id, name, items = [], placement = :default, before = nil, type = :default, href = nil)
      super
    end

    def features
      Array(items).collect(&:feature).compact
    end

    def visible?(userid)
      auth  = store.can?(id) && User.current_user.role_allows_any?(:identifiers => tab)
      $log.debug("Role Authorization #{auth ? "successful" : "failed"} for: userid [#{userid}], main tab [#{id}]")
      auth
    end

    def url
      case type
      when :big_iframe then "/dashboard/iframe?sid=#{id}"
      else                  "/dashboard/maintab/?tab=#{id}"
      end
    end
  end
end
