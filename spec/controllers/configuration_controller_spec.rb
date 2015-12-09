require "spec_helper"

describe ConfigurationController do
  [[0, "12AM-1AM"],
   [7, "7AM-8AM"],
   [11, "11AM-12PM"],
   [18, "6PM-7PM"],
   [19, "7PM-8PM"],
   [23, "11PM-12AM"]].each do |io|
    context ".get_hr_str" do
      it "should return interval for #{io[0]} o'clock: #{io[1]}" do
        interval = controller.get_hr_str(io[0])
        expect(interval).to eql(io[1])
      end
    end
  end

  context "#set_form_vars" do
    before do
      MiqSearch.seed
    end

    it "#successfully sets all_view_tree for default filters tree" do
      controller.instance_variable_set(:@tabform, "ui_3")
      controller.send(:set_form_vars)
      expect(assigns(:all_views_tree)).not_to be_nil
    end
  end
end
