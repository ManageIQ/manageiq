require "spec_helper"

describe VmOrTemplateController do
  context "#snap_pressed" do
    before :each do
      set_user_privileges
      controller.stub(:role_allows).and_return(true)
      vm = FactoryGirl.create(:vm_vmware)
      @snapshot = FactoryGirl.create(:snapshot, :vm_or_template_id => vm.id,
                                                :name              => 'EvmSnapshot',
                                                :description       => "Some Description"
      )
      vm.snapshots = [@snapshot]
      @tree_hash = {
        :trees       => {
          :vandt_tree => {
            :active_node => "v-#{vm.id}"
          }
        },
        :active_tree => :vandt_tree
      }
    end
    it "snapshot node exists in tree" do
      controller.instance_variable_set(:@_params, :id => @snapshot.id)
      controller.instance_variable_set(:@temp, {})
      controller.instance_variable_set(:@sb, @tree_hash)
      controller.should_receive(:render)
      controller.snap_pressed
      controller.send(:flash_errors?).should_not be_true
    end

    it "when snapshot is selected center toolbars are replaced" do
      session[:sandboxes] = HashWithIndifferentAccess.new.merge!(:vm_or_template => @tree_hash)
      controller.instance_variable_set(:@temp, {})
      post :snap_pressed, :id => @snapshot.id
      expect(response.body).to include("center_buttons_div")
    end

    it "deleted node pressed in snapshot tree" do
      controller.instance_variable_set(:@_params, :id => "some_id")
      controller.instance_variable_set(:@temp, {})
      controller.instance_variable_set(:@sb, @tree_hash)
      controller.should_receive(:build_snapshot_tree)
      controller.should_receive(:render)
      controller.snap_pressed
      controller.send(:flash_errors?).should be_true
    end
  end
end
