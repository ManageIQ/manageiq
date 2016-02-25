module Menu
  Section = Struct.new(:id, :name, :icon, :items, :placement, :before, :type, :href) do
    def initialize(an_id, name, icon, items = [], placement = :default, before = nil, type = :default, href = nil)
      super
    end

    def features
      Array(items).collect { |el| el.try(:feature) || el.try(:features) }.flatten.compact
    end

    def visible?
      userid = User.current_userid
      store = Vmdb::PermissionStores.instance
      auth  = store.can?(id) && User.current_user.role_allows_any?(:identifiers => features)
      $log.debug("Role Authorization #{auth ? "successful" : "failed"} for: userid [#{userid}], main tab [#{id}]")
      auth
    end

    def subsection?
      @subsection ||= Array(items).detect { |el| el.kind_of?(Section) }
    end

    def url
      case type
      when :big_iframe then "/dashboard/iframe?sid=#{id}"
      else                  "/dashboard/maintab/?tab=#{id}"
      end
    end

    def leaf?
      false
    end
  end
end
