module Menu
  Item = Struct.new(:id, :name, :feature, :rbac_feature, :href, :type) do
    def initialize(an_id, a_name, features, rbac_feature, href, type = :default)
      super
      @parent = nil
      @name = a_name.kind_of?(Proc) ? a_name : -> { a_name }
    end

    attr_accessor :parent

    def name
      @name.call
    end

    def visible?
      ApplicationHelper.role_allows?(rbac_feature)
    end

    def url
      case type
      when :big_iframe then "/dashboard/iframe?id=#{id}"
      else                  href
      end
    end

    def leaf?
      true
    end

    def parent_path
      @parent.parent_path
    end

    def item(item_id)
      item_id == id ? self : nil
    end
  end
end
