module Menu
  Item = Struct.new(:id, :name, :feature, :rbac_feature, :href, :type) do
    def initialize(an_id, name, features, rbac_feature, href, type = :default)
      super
    end

    def visible?
      ApplicationHelper.role_allows_intern(rbac_feature)
    end

    def url
      case type
      when :big_iframe then "/dashboard/iframe?id=#{id}"
      else                  href
      end
    end
  end
end
