module Menu
  Item = Struct.new(:id, :name, :feature, :rbac_feature, :href, :type) do
    def initialize(an_id, a_name, features, rbac_feature, href, type = :default)
      super
      @name = a_name.kind_of?(Proc) ? a_name : lambda { a_name }
    end

    def name
      @name.call
    end

    def visible?(userid)
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
