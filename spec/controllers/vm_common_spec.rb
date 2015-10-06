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
      tree_hash = {
        :trees       => {
          :vandt_tree => {
            :active_node => "v-#{vm.id}"
          }
        },
        :active_tree => :vandt_tree
      }

      session[:sandboxes] = {"vm_or_template" => tree_hash}
    end

    it "snapshot node exists in tree" do
      post :snap_pressed, :id => @snapshot.id
      expect(response).to render_template('vm_common/_snapshots_tree')
      expect(assigns(:flash_array)).to be_blank
    end

    it "when snapshot is selected center toolbars are replaced" do
      post :snap_pressed, :id => @snapshot.id
      expect(response).to render_template('vm_common/_snapshots_tree')
      expect(response.body).to include("center_buttons_div")
      expect(assigns(:flash_array)).to be_blank
    end

    it "deleted node pressed in snapshot tree" do
      controller.should_receive(:build_snapshot_tree)
      post :snap_pressed, :id => "some_id"
      expect(response).to render_template('vm_common/_snapshots_tree')
      expect(assigns(:flash_array).first[:message]).to eq("Last selected Snapshot no longer exists")
      expect(assigns(:flash_array).first[:level]).to eq(:error)
    end
  end
end
