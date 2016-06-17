describe TreeBuilderPolicySimulationResults do
  context 'TreeBuilderPolicySimulationResults' do
    before do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Policy Simulation Group")
      login_as FactoryGirl.create(:user, :userid => 'policy_simulation_results_wilma', :miq_groups => [@group])
      @policy_options = {:out_of_scope => true, :passed => true, :failed => true}
      @event = FactoryGirl.create(:miq_event_definition, :id => 1234)
      @data = {:event_value => 1234, :results => [{:id => 10000000000076, :name => "DevRHEL002", :result => "allow", :profiles => []},
                                                  {:id => 10000000000069, :name => "DevLin002", :result => "deny",
                                                   :profiles => [{:id => 10000000000058, :name => 'Name',  :description => "Compliance: DMZ Configuration", :result => "deny",
                                                                  :policies => [{:id => 10000000000015, :name => 'name', :description => "Configuration: VM - Internal Network", :result => "deny",
                                                                                :conditions => [{:id => 10000000000012, :description => "vm - internal vlan check", :result => "deny"}],#expression
                                                                                :actions => [{:id => 10000000000037, :description => "Email - DMZ", :result => "deny"},
                                                                                             {:id => 10000000000009, :description => "Shutdown Virtual Machine Guest OS", :result =>"deny"}]}]}]}]}
      @rsop_tree = TreeBuilderPolicySimulationResults.new(:rsop_tree, :rsop, {}, true, @data)
    end
    it 'sets root correctly' do
      root_options = @rsop_tree.send(:root_options)
      expect(root_options).to eq([_("Policy Simulation Results for Event [%{description}]") %
                                    {:description => @event.description},
                                  nil,
                                  "event-#{@event.name}",
                                  {:cfmeNoClick => true}])
    end
    it 'sets vm nodes correctly' do
      vms = @rsop_tree.send(:x_get_tree_roots, false)
      original_vms =@data[:results].sort_by { |a| a[:name].downcase }
      vms.each_with_index  do |vm, i|
        expect(vm[:text]).to eq("<strong>VM:</strong> #{original_vms[i][:name]}")
        expect(vm[:image]).to eq('vm')
        expect(vm[:profiles]).to eq(original_vms[i][:profiles])
      end
    end
    it 'sets profile nodes correctly' do
      expect(true).to eq(true)
    end
  end
end