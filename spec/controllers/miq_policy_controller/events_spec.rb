describe MiqPolicyController do
  context "::Events" do
    context "#event_edit" do
      before :each do
        stub_user(:features => :all)
        @action = FactoryGirl.create(:miq_action, :name => "compliance_failed")
        @event = FactoryGirl.create(:miq_event_definition, :name => "vm_compliance_check")
        @policy = FactoryGirl.create(:miq_policy, :name => "Foo")

        controller.instance_variable_set(:@sb,
                                         :node_ids    => {
                                           :policy_tree => {"p" => @policy.id}
                                         },
                                         :active_tree => :policy_tree
                                        )
        allow(controller).to receive(:replace_right_cell)
      end

      it "saves Policy Event with an action" do
        new_hash = {
          :name          => "New Name",
          :description   => "New Description",
          :actions_true  => [[@action.name, true, @action.id]],
          :actions_false => []
        }
        edit = {
          :new      => new_hash,
          :current  => new_hash,
          :key      => "event_edit__#{@event.id}",
          :event_id => @event.id
        }
        controller.instance_variable_set(:@edit, edit)
        session[:edit] = edit
        controller.instance_variable_set(:@_params, :id => @event.id.to_s, :button => "save")
        controller.event_edit
        expect(@policy.actions_for_event(@event, :success)).to include(@action)
      end

      it "does not allow to save Policy Event without an action" do
        new_hash = {
          :name          => "New Name",
          :description   => "New Description",
          :actions_true  => [],
          :actions_false => []
        }
        edit = {
          :new      => new_hash,
          :current  => new_hash,
          :key      => "event_edit__#{@event.id}",
          :event_id => @event.id
        }
        controller.instance_variable_set(:@edit, edit)
        session[:edit] = edit
        controller.instance_variable_set(:@_params, :id => @event.id.to_s, :button => "save")
        expect(controller).to receive(:render)
        controller.event_edit
        expect(assigns(:flash_array).first[:message]).to include("At least one action must be selected to save this Policy Event")
      end
    end
  end
end
