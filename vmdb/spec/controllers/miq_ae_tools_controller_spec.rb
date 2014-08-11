require "spec_helper"

describe MiqAeToolsController do
  before(:each) do
    set_user_privileges
  end

  context "#form_field_changed" do
    it "resets target id to nil, when target class is <none>" do
      new = {
        :target_class => "EmsCluster",
        :target_id    => 1
      }
      controller.instance_variable_set(:@resolve, :throw_ready => true, :new => new)
      controller.should_receive(:render)
      controller.instance_variable_set(:@_params, :target_class => '', :id => 'new')
      controller.send(:form_field_changed)
      assigns(:resolve)[:new][:target_class].should eq('')
      assigns(:resolve)[:new][:target_id].should eq(nil)
    end
  end
end
