module Menu
  class Manager
    include Singleton

    class << self
      extend Forwardable

      delegate [:menu, :tab_features_by_id, :tab_features_by_name, :tab_name,
                :each_feature_title_with_subitems, :item_in_section?, :item, 
                :section, :section_id_string_to_symbol] => :instance
    end

    private

    class InvalidMenuDefinition < Exception
    end

    def menu(placement = :default)
      @menu.each do |menu_section|
        yield menu_section if menu_section.placement == placement
      end
    end

    def item(item_id)
      @menu.each do |menu_section|
        the_item = menu_section.items.detect { |item| item.id == item_id }
        return the_item if the_item.present?
      end
    end

    def section(section_id)
      if section_id.kind_of?(String) # prevent .to_sym call on section_id
        section_id = @id_to_section.keys.detect { |k| k.to_s == section_id }
      end
      @id_to_section[section_id]
    end

    def item_in_section?(item_id, section_id)
      @id_to_section[section_id].items.collect(&:id).include?(item_id)
    end

    def tab_features_by_id(tab_id)
      @id_to_section[tab_id].features
    end

    def tab_features_by_name(tab_name)
      @name_to_section[tab_name].features
    end

    def each_feature_title_with_subitems
      @menu.each { |section| yield section.name, section.features }
    end

    def tab_name(tab_id)
      @id_to_section[tab_id].name
    end

    def initialize
      load_default_items
      load_custom_items
    end

    def merge_sections(sections)
      sections.each do |section|
        if section.before
          position = @menu.index { |existing_section| existing_section.id == section.before }
          @menu.insert(position, section)
        else
          @menu << section
        end
      end
    end

    def merge_items(items)
      items.each do |item|
        raise InvalidMenuDefinition, 'Invalid parent' unless @id_to_section.key?(item.parent)
        @id_to_section[item.parent].items << item
      end
    end

    def load_custom_items
      sections, items = Menu::CustomLoader.load
      merge_sections(sections)
      preprocess_sections
      merge_items(items)
    end

    def load_default_items
      @menu = Menu::DefaultMenu.default_menu
      preprocess_sections
    end

    def preprocess_sections
      @id_to_section   = @menu.index_by(&:id)
      @name_to_section = @menu.index_by(&:name)
    end

    #
    # Takes section id as string and returns section id symbol or null.
    #
    # Prevent calling to_sym on user input by using this method.
    #
    def section_id_string_to_symbol(section_id_string)
      valid_sections[section_id_string]
    end

    def valid_sections
      # format is {"vi" => :vi, "svc" => :svc . . }
      @valid_sections ||= @menu.each_with_object({}) { |section, acc| acc[section.id.to_s] = section.id }
    end
  end
end
