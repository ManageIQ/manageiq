describe MiqPolicyController do
  context "::Conditions" do
    context '#condition_remove' do
      it 'removes condition successfully' do
        login_as FactoryGirl.create(:user, :features => "condition_remove")
        condition = FactoryGirl.create(:condition)
        policy = FactoryGirl.create(:miq_policy, :name => "test_policy", :conditions => [condition])
        controller.instance_variable_set(:@_params, :policy_id => policy.id, :id => condition.id)
        controller.instance_variable_set(:@sb, {})
        controller.x_node = "pp_pp-1r36_p-#{policy.id}_co-#{condition.id}"
        expect(controller).to receive(:replace_right_cell)
        controller.send(:condition_remove)
        policy.reload
        expect(assigns(:flash_array).first[:message]).to include("has been removed from Policy")
        expect(policy.conditions).to eq([])
      end
    end
  end
end
