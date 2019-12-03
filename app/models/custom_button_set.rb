class CustomButtonSet < ApplicationRecord
  acts_as_miq_set

  before_save :update_button_order
  after_save :update_children

  def update_button_order
    if set_data.try(:[], :button_order).nil?
      self.set_data ||= {}
      set_data[:button_order] ||= []
    end

    children = Set.new(Rbac.filtered(CustomButton.where(:id => set_data[:button_order])).pluck(:id))

    # remove obsolete entries from button_order
    set_data[:button_order].select! do |button_id|
      children.include?(button_id)
    end
  end

  def update_children
    if set_data.try(:[], :button_order).nil?
      remove_all_children
      return
    end

    children = Rbac.filtered(CustomButton.where(:id => set_data[:button_order]))
    replace_children(children)
  end

  def self.find_all_by_class_name(class_name, class_id = nil)
    ordering = ->(o) { [o.set_data[:group_index].to_s, o.name] }

    case class_name
    when "ServiceTemplate"
      # for services we need to show custom buttons for a specific Services parent ServiceTemplate and for all Services
      applies_to_instance(class_name, class_id).sort_by(&ordering) +
        applies_to_all_instances("Service").sort_by(&ordering)
    when "GenericObjectDefinition"
      # for generic objects we need to show custom buttons for a specific generic object's parent GenericObjectDefinition
      # and for all Generic Objects
      applies_to_instance(class_name, class_id).sort_by(&ordering) +
        applies_to_all_instances("GenericObject").sort_by(&ordering)
    else
      applies_to_all_instances(class_name).sort_by(&ordering)
    end
  end

  def self.applies_to_class(class_name)
    where("set_data like ?", "%:applies_to_class: #{class_name}%")
  end

  def self.applies_to_instance(class_name, id)
    applies_to_class(class_name).where("set_data like ?", "%:applies_to_id: #{id.to_i}%")
  end

  def self.applies_to_all_instances(class_name)
    applies_to_class(class_name).where("set_data not like ?", "%:applies_to_id%")
  end

  # Params:
  #   custom_button_sets: <Array>CustomButtonSet
  #   object: for this object are evaluated visibility_expression of CustomButtons
  #           one CustomButtonSet contains any CustomButtons,
  #           CustomButtonSet has stored this ids of CustomButtons in array CustomButton#set_data[:button_order]
  # Returns:
  #   <Array>CustomButtonSet
  #
  # example:
  # let's have:
  # custom_buttons_set =
  #   <Array> [<CustomButtonSet> id: 10000000000075,
  #     set_data:
  #       {:button_order=> [1, 2]}, list ids of custom buttons in custom button set (group of buttons in UI)
  # ... ]
  # object = Vm.first
  #
  # then CustomButtonSet.filter_with_visibility_expression(custom_button_sets, object) returns:
  #  - same custom_button_sets array when all visibility expressions are not populated(CustomButton#visibility_expression = nil)
  #  - same custom_button_sets array but with filtered list custom buttons ids in each custom button set from
  #    custom_button_sets when any visibility expression is evaluated to true
  #    - ids of custom buttons with visibility expression which are evaluated to false are removed from CustomButtonSet#set_data[:button_order]
  #  - filtered custom_button_sets array when all visibilty expression custom buttons have been evaluated to false
  def self.filter_with_visibility_expression(custom_button_sets, object)
    custom_button_sets.each_with_object([]) do |custom_button_set, ret|
      custom_button_from_set = CustomButton.where(:id => custom_button_set.custom_buttons.pluck(:id)).select(:id, :visibility_expression).with_array_order(custom_button_set.set_data[:button_order])
      filtered_ids = custom_button_from_set.select { |x| x.evaluate_visibility_expression_for(object) }.pluck(:id)
      if filtered_ids.present?
        custom_button_set.set_data[:button_order] = filtered_ids
        ret << custom_button_set
      end
      ret
    end
  end

  def deep_copy(options)
    raise ArgumentError, "options[:owner] is required" if options[:owner].blank?

    options.each_with_object(dup) { |(k, v), button_set| button_set.send("#{k}=", v) }.tap do |cbs|
      cbs.guid = SecureRandom.uuid
      cbs.name = "#{name}-#{cbs.guid}"
      cbs.set_data[:button_order] = []
      cbs.set_data[:applies_to_id] = options[:owner].id
      cbs.save!
      custom_buttons.each do |cb|
        cb_copy = cb.copy(:applies_to => options[:owner])
        cbs.add_member(cb_copy)
        options[:owner][:options][:button_order] ||= []
        options[:owner][:options][:button_order] << "cb-#{cb_copy.id}"
        cbs.set_data[:button_order] << cb_copy.id
        options[:owner].save!
        cbs.save!
      end
    end
  end

  def self.display_name(number = 1)
    n_('Button Group', 'Button Groups', number)
  end
end
