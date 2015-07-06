class CustomButtonSet < ActiveRecord::Base
  acts_as_miq_set

  default_scope  { where conditions_for_my_region_default_scope }

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
end
