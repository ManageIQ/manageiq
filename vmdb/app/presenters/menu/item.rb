module Menu
  Item = Struct.new(:id, :_name, :feature, :rbac_feature, :href, :type) do
    def initialize(an_id, _name, features, rbac_feature, href, type = :default)
      super
    end

    def name
      _name.kind_of?(Proc) ? _name.call : _name
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
