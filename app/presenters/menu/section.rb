module Menu
  Section = Struct.new(:id, :name, :icon, :items, :placement, :before, :type, :href) do
    def initialize(an_id, name, icon, *args)
      super
      self.items ||= []
      self.placement ||= :default
      self.type ||= :default

      @parent = nil
      items.each { |el| el.parent = self }
    end

    attr_accessor :parent

    def features
      Array(items).collect { |el| el.try(:feature) }.compact
    end

    def features_recursive
      Array(items).collect { |el| el.try(:feature) || el.try(:features) }.flatten.compact
    end

    def visible?
      userid = User.current_userid
      store = Vmdb::PermissionStores.instance
      auth  = store.can?(id) && User.current_user.role_allows_any?(:identifiers => features_recursive)
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

    def contains_item_id?(item_id)
      items.detect do |el|
        el.id == item_id || (el.kind_of?(Section) && el.contains_item_id?(item_id))
      end.present?
    end

    def default_redirect_url
      items.each do |item|
        next unless item.visible?
        if item.kind_of?(Item)
          return item.url
        else
          section_result = item.default_redirect_url
          return section_result if section_result
        end
      end
      false
    end

    def preprocess_sections(section_hash)
      items.each do |el|
        if el.kind_of?(Section)
          section_hash[el.id] = el
          el.preprocess_sections(section_hash)
        end
      end
    end

    def section_path(acc = [])
      acc << id
      @parent.present? ? @parent.parent_path(acc) : acc
    end
  end
end
