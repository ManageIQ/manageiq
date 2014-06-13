require "spec_helper"

describe CustomButtonSet do
  context "find_all_by_class_name" do
    it "should return all Service and ServiceTemplate buttons only, when ServiceTemplate class is passed in" do
      set_data = { :applies_to_class => "Service", :group_index => 2 }
      button_set1 = FactoryGirl.create(:custom_button_set, :name => "set1", :set_data => set_data)
      button_set1.save!

      set_data = {:applies_to_class => "ServiceTemplate", :applies_to_id => 1, :group_index => 1}
      button_set2 = FactoryGirl.create(:custom_button_set, :name => "set2", :set_data => set_data)
      button_set2.save!

      set_data = {:applies_to_class => "Vm", :group_index => 3 }
      button_set3 = FactoryGirl.create(:custom_button_set, :name => "set3", :set_data => set_data)
      button_set3.save!

      button_sets = CustomButtonSet.find_all_by_class_name("ServiceTemplate", 1)
      button_sets.count.should == 2

      all_button_sets = CustomButtonSet.find(:all)
      all_button_sets.count.should == 3
    end
  end
end
