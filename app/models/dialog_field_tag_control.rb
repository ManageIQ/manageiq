class DialogFieldTagControl < DialogFieldSortedItem
  def initialize_with_values(dialog_values)
    @value = value_from_dialog_fields(dialog_values) || get_default_value
  end

  def category=(id)
    options[:category_id] = id
  end

  def category
    options[:category_id]
  end

  def category_name
    options[:category_name]
  end

  def category_description
    options[:category_description]
  end

  def single_value?
    return true if options[:force_single_value]

    !!Classification.find_by(:id => category).try(:single_value)
  end

  def force_single_value=(setting)
    options[:force_single_value] = setting
  end

  def self.allowed_tag_categories
    tag_cats = Classification.where(:show => true, :parent_id => 0, :read_only => false).includes(:tag).to_a

    return [] if tag_cats.blank?

    categories = tag_cats.collect do |cat|
      {:id => cat.id, :description => cat.description, :single_value => cat.single_value}
    end
    categories.sort_by { |tag| tag[:description] }
  end

  def value_from_dialog_fields(dialog_values)
    value = dialog_values[automate_key_name]
    value.gsub(/Classification::/, '') if value
  end

  def values
    category = Classification.find_by(:id => self.category)
    return [] if category.nil?

    sort_field = sort_by
    sort_field = :name if sort_field == :value
    available_tags = category.entries.collect do |c|
      {:id => c.id, :name => c.name, :description => c.description}
    end

    empty = required? ? "<Choose>" : "<None>"
    blank_value = [{:id => nil, :name => empty, :description => empty}]

    return blank_value + available_tags if sort_field == :none

    if data_type == "integer"
      available_tags.sort_by! { |cat| cat[sort_field].to_i }
    else
      available_tags.sort_by! { |cat| cat[sort_field] }
    end

    available_tags.reverse! if sort_order == :descending

    available_tags = blank_value + available_tags
    available_tags
  end

  def automate_output_value
    MiqAeEngine.create_automation_attribute_array_value(Classification.where(:id => @value.to_s.split(",")))
  end

  def automate_key_name
    MiqAeEngine.create_automation_attribute_array_key(super)
  end
end
