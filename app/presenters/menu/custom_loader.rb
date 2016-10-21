module Menu
  class CustomLoader
    include Singleton

    def self.load
      instance.load_custom_items
    end

    def load_custom_items
      @sections = []
      @items    = []
      Dir.glob(File.join(File.dirname(__FILE__), "../../../product/menubar/*.yml")).each do |f|
        load_custom_item(f)
      end
      [@sections, @items]
    end

    private

    def load_custom_item(file_name)
      properties = YAML.load(File.open(file_name))
      if properties['type'] == 'section'
        @sections << create_custom_menu_section(properties)
      else
        @items << create_custom_menu_item(properties)
      end
    end

    def create_custom_menu_item(properties)
      rbac = properties['rbac'].each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      item_type = properties.key?('item_type') ? properties['item_type'].to_sym : :default
      %w(id name rbac parent).each do |property|
        raise Menu::Manager::InvalidMenuDefinition,
              "incomplete definition -- missing #{property}" if properties[property].blank?
      end
      item = Item.new(properties['id'],
                            properties['name'],
                            properties['feature'],
                            rbac,
                            properties['href'],
                            item_type)
      item.parent = properties['parent'].to_sym
      item
    end

    def create_custom_menu_section(properties)
      icon         = properties.key?('icon') ? properties['icon'] : nil
      placement    = properties.key?('placement') ? properties['placement'].to_sym : :default
      before       = properties.key?('before') ? properties['before'].to_sym : nil
      section_type = properties.key?('section_type') ? properties['section_type'].to_sym : :default
      href         = properties.key?('href') ? properties['href'].to_sym : nil
      Section.new(properties['id'].to_sym, properties['name'], icon, [], placement, before, section_type, href)
    end
  end
end
