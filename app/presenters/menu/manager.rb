module Menu
  class Manager
    include Singleton

    class << self
      extend Forwardable

      delegate %i(menu item_in_section? item section section_id_string_to_symbol each) => :instance
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
        menu_section.items.each do |el|
          the_item = el.item(item_id)
          return the_item if the_item.present?
        end
      end
      nil
    end

    def section(section_id)
      # prevent .to_sym call on section_id
      section_id = section_id_string_to_symbol(section_id) if section_id.kind_of?(String)
      @id_to_section[section_id]
    end

    def item_in_section?(item_id, section_id)
      @id_to_section[section_id].contains_item_id?(item_id)
    end

    def each
      @menu.each { |section| yield section }
    end

    def initialize
      load_default_items
      load_custom_items
    end

    def merge_sections(sections)
      sections.each do |section|
        position = nil
        if section.before
          position = @menu.index { |existing_section| existing_section.id == section.before }
        end

        if position
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
        item.parent = @id_to_section[item.parent]
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
      @id_to_section = @menu.index_by(&:id)
      # recursively add subsections to the @id_to_section hash
      @menu.each do |section|
        section.preprocess_sections(@id_to_section)
      end
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
      @valid_sections ||= @id_to_section.keys.index_by(&:to_s)
    end
  end
end
