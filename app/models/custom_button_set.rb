class CustomButtonSet < ApplicationRecord
  acts_as_miq_set

  def self.find_all_by_class_name(class_name, class_id = nil)
    ordering = ->(o) { [o.set_data[:group_index].to_s, o.name] }

    case class_name
    when "ServiceTemplate"
      # for services we need to show custom buttons for a specific Services parent ServiceTemplate and for all Services
      applies_to_instance(class_name, class_id).sort_by(&ordering) +
        applies_to_all_instances("Service").sort_by(&ordering)
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

  def deep_copy(options)
    raise ArgumentError, "options[:owner] is required" if options[:owner].blank?

    options.each_with_object(dup) { |(k, v), button_set| button_set.send("#{k}=", v) }.tap do |cbs|
      cbs.guid = MiqUUID.new_guid
      cbs.name = "#{name}-#{cbs.guid}"
      cbs.save!
      custom_buttons.each { |cb| cbs.add_member(cb.copy(:applies_to => options[:owner])) }
    end
  end
end
