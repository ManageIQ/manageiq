require "spec_helper"

describe ChargebackController do
  before(:each) do
    set_user_privileges
  end

  context "returns current rate assignments or set them to blank if category/tag is deleted" do
    before(:each) do
      @category = FactoryGirl.create(:classification, :description => "Environment", :name => "environment")
      @tag = FactoryGirl.create(:classification,
                                :description => "Test category",
                                :name        => "test_category",
                                :parent_id   => @category.id)
      options = {:parent_id => @tag.id, :name => "test_entry", :description => "Test entry under test category"}
      @entry = FactoryGirl.create(:classification, options)
      cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Storage")
      temp = {:cb_rate => cbr, :tag => [@tag, "vm"]}
      ChargebackRate.set_assignments(:Storage, [temp])
    end

    context "#get_tags_all" do
      it "returns the classification entry record" do
        controller.instance_variable_set(:@edit, :cb_assign => {:tags => {}})
        controller.send(:get_tags_all, @tag.id)
        assigns(:edit)[:cb_assign][:tags].should eq(@entry.id.to_s => @entry.description)
      end

      it "returns empty hash when classification entry is not found" do
        controller.instance_variable_set(:@edit, :cb_assign => {:tags => {}})
        controller.send(:get_tags_all, 1)
        assigns(:edit)[:cb_assign][:tags].should eq({})
      end
    end

    context "#cb_assign_set_form_vars" do
      it "returns tag for current assignments" do
        controller.instance_variable_set(:@sb,
                                         :active_tree => :cb_assignments_tree,
                                         :trees       => {:cb_assignments_tree => {:active_node => 'xx-Storage'}})
        controller.send(:cb_assign_set_form_vars)
        tag = assigns(:edit)[:current_assignment][0][:tag][0]
        tag['parent_id'].should eq(@category.id)
      end

      it "returns empty array for current_assignment when tag/category is not found" do
        @tag.destroy
        controller.instance_variable_set(:@sb,
                                         :active_tree => :cb_assignments_tree,
                                         :trees       => {:cb_assignments_tree => {:active_node => 'xx-Storage'}})
        controller.send(:cb_assign_set_form_vars)
        assigns(:edit)[:current_assignment].should eq([])
      end
    end
  end
end
