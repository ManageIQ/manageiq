require "spec_helper"
include UiConstants

describe ReportController do
  context "::Reports" do
    context "#check_tabs" do
      tabs = {
          :formatting    => 2,
          :filter        => 3,
          :summary       => 4,
          :charts        => 5,
          :timeline      => 6,
          :preview       => 7,
          :consolidation => 8,
          :styling       => 9
      }
      tabs.each_pair do |tab_title, tab_number|
        title = tab_title.to_s.titleize
        it "check existence of flash message when tab is changed to #{title} without selecting fields" do
          user = FactoryGirl.create(:user)
          session[:userid] = user.userid
          controller.instance_variable_set(:@sb, {})
          controller.instance_variable_set(:@edit, :new => {:fields => []})
          controller.instance_variable_set(:@_params, :tab => "new_#{tab_number}")
          controller.send(:check_tabs)
          flash_messages = assigns(:flash_array)
          flash_str = "#{title} tab is not available until at least 1 field has been selected"
          flash_messages.first[:message].should eq(flash_str)
          flash_messages.first[:level].should eq(:error)
        end

        it "flash messages should be nil when tab is changed to #{title} after selecting fields" do
          user = FactoryGirl.create(:user)
          session[:userid] = user.userid
          controller.instance_variable_set(:@sb, {})
          controller.instance_variable_set(:@edit, :new => {
                                                      :fields  => [["Date Created", "Vm-ems_created_on"]],
                                                      :sortby1 => "some_field"
                                                  })
          controller.instance_variable_set(:@_params, :tab => "new_#{tab_number}")
          controller.send(:check_tabs)
          assigns(:flash_array).should be_nil
        end
      end
    end
  end
end
