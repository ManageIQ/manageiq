class CustomButtonSet < ActiveRecord::Base
  acts_as_miq_set

  default_scope  { where self.conditions_for_my_region_default_scope }

  def self.find_all_by_class_name(class_name, class_id=nil)
    if class_name == "ServiceTemplate"
      # for services we need to show custom buttons for a specific Services parent ServiceTemplate and for all Services
      self.where(["set_data like ? AND set_data like ?", "%:applies_to_class: #{class_name}%", "%:applies_to_id: #{class_id.to_i}%"]).all.sort{|a,b| a.set_data[:group_index].to_s + a.name <=> b.set_data[:group_index].to_s + b.name } +
        self.where(["set_data like ? AND set_data not like ?", "%:applies_to_class: Service%", "%:applies_to_id%"]).all.sort{|a,b| a.set_data[:group_index].to_s + a.name <=> b.set_data[:group_index].to_s + b.name }
    else
      self.where(["set_data like ? AND set_data not like ?", "%:applies_to_class: #{class_name}%", "%:applies_to_id%"]).all.sort{|a,b| a.set_data[:group_index].to_s + a.name <=> b.set_data[:group_index].to_s + b.name }
    end
  end
end
