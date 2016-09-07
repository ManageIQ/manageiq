describe ServiceLoadBalancer do
  let(:manager_by_setter)      { manager_by_dialog }
  let(:manager_by_dialog)      { FactoryGirl.create(:ems_amazon).network_manager }
  let(:deployed_load_balancer) { FactoryGirl.create(:load_balancer_amazon) }

  let(:dialog_options) do
    {
      'dialog_load_balancer_manager' => manager_by_dialog.id,
      'dialog_load_balancer_name'    => 'test123',
      'dialog_vms'                   => "#{vm_1.id},#{vm_2.id}",
      'dialog_cloud_subnets'         => "#{cloud_subnet.id}",
      'dialog_security_groups'       => "#{security_group.id}",
    }
  end

  let(:vm_1) { FactoryGirl.create("vm_amazon".to_sym, :name => "Instance 1") }
  let(:vm_2) { FactoryGirl.create("vm_amazon".to_sym, :name => "Instance 2") }
  let(:cloud_subnet) { FactoryGirl.create("cloud_subnet_amazon".to_sym, :name => "Subnet") }
  let(:security_group) { FactoryGirl.create("security_group_amazon".to_sym, :name => "Sec group 2") }

  let(:service) do
    FactoryGirl.create(:service_load_balancer,
      :evm_owner => FactoryGirl.create(:user),
      :miq_group => FactoryGirl.create(:miq_group))
  end

  let(:service_with_dialog_options) do
    service.load_balancer_manager = manager_by_dialog
    service.options               = {:dialog => dialog_options}
    service
  end

  let(:service_mix_dialog_setter) do
    service.load_balancer_manager = manager_by_setter
    service.options               = {:dialog => dialog_options}
    service
  end

  let(:service_with_deployed_load_balancer) do
    service_mix_dialog_setter.add_resource(deployed_load_balancer)
    service_mix_dialog_setter
  end

  context "#load_balancer_name" do
    it "gets load_balancer name from dialog options" do
      expect(service_with_dialog_options.load_balancer_name).to eq('test123')
    end

    it "gets load_balancer name from overridden value" do
      service_with_dialog_options.load_balancer_name = "new_name"
      expect(service_with_dialog_options.load_balancer_name).to eq("new_name")
    end
  end

  context "#load_balancer_options" do
    before do
      allow_any_instance_of(ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerServiceOptionConverter).to(
        receive(:load_balancer_create_options).and_return(dialog_options))
    end

    it "gets load_balancer options set by dialog" do
      expect(service_with_dialog_options.load_balancer_options).to eq(dialog_options)
    end

    context "cloud tenant option" do
      it "excludes the tenant option when it is nil" do
        dialog_options['dialog_tenant_name'] = nil
        expect(service_with_dialog_options.load_balancer_options).not_to include(:tenant_name)
      end

      it "excludes the tenant option when it is empty" do
        dialog_options['dialog_tenant_name'] = ''
        expect(service_with_dialog_options.load_balancer_options).not_to include(:tenant_name)
      end
    end

    it "gets load_balancer options from overridden values" do
      new_options = {"any_key" => "any_value"}
      service_with_dialog_options.load_balancer_options = new_options
      expect(service_with_dialog_options.load_balancer_options).to eq(new_options)
    end

    it "encrypts password when saves to DB" do
      new_options = {:parameters => {"my_password" => "secret"}}
      service_with_dialog_options.load_balancer_options = new_options
      expect(service_with_dialog_options.options[:create_options][:parameters]["my_password"]).to eq(MiqPassword.encrypt("secret"))
    end

    it "prefers the load_balancer manager set by dialog" do
      expect(service_mix_dialog_setter.load_balancer_manager).to eq(manager_by_setter)
      service_mix_dialog_setter.load_balancer_options
      expect(service_mix_dialog_setter.load_balancer_manager).to eq(manager_by_dialog)
    end
  end

  context '#deploy_load_balancer' do
    it 'creates a load_balancer through cloud manager' do
      allow(ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer).to receive(:raw_create_load_balancer) do |manager, name, opts|
        expect(manager).to eq(manager_by_setter)
        expect(name).to eq('test123')
        expect(opts).to be_kind_of Hash
      end

      service_mix_dialog_setter.deploy_load_balancer
    end

    it 'always saves options even when the manager fails to create a load_balancer' do
      provision_error = MiqException::MiqLoadBalancerProvisionError
      allow_any_instance_of(ManageIQ::Providers::Amazon::NetworkManager).to receive(:load_balancer_create).and_raise(provision_error, 'test failure')

      expect(service_mix_dialog_setter).to receive(:save_create_options)
      expect { service_mix_dialog_setter.deploy_load_balancer }.to raise_error(provision_error)
    end
  end

  context '#update_load_balancer' do
    let(:reconfigurable_service) do
      service_template = FactoryGirl.create(:service_template_load_balancer)

      service.service_template      = service_template
      service.load_balancer_manager = manager_by_setter
      service.add_resource(deployed_load_balancer)
      service.update_options = service.build_load_balancer_options_from_dialog(dialog_options)
      service
    end

    it 'updates a load_balancer through cloud manager' do
      expect { reconfigurable_service.update_load_balancer }.to raise_error(
        MiqException::MiqLoadBalancerUpdateError, 'Not supported')
    end
  end

  context '#load_balancer_status' do
    it 'returns an error if load_balancer has never been deployed' do
      status, _message = service_mix_dialog_setter.load_balancer_status
      expect(status).to eq('check_status_failed')
    end

    it 'returns current load_balancer status through provider' do
      allow(deployed_load_balancer).to receive(:raw_status).and_return('create_complete')

      status, message = service_with_deployed_load_balancer.load_balancer_status
      expect(status).to eq('create_complete')
      expect(message).to eq(nil)
    end

    it 'returns an error message when the provider fails to retrieve the status' do
      allow(deployed_load_balancer).to receive(:raw_status).and_raise(MiqException::MiqLoadBalancerStatusError, 'test failure')

      status, message = service_with_deployed_load_balancer.load_balancer_status
      expect(status).to eq('create_complete')
      expect(message).to eq(nil)
    end
  end

  context '#all_vms' do
    it 'returns all vms from a deployed load_balancer' do
      # TODO(lsmola) we need to make the spec for all providers and move it to provider gem
      t = 'amazon'
      @load_balancer_2             = FactoryGirl.create("load_balancer_#{t}".to_sym)
      @load_balancer_pool          = FactoryGirl.create("load_balancer_pool_#{t}".to_sym)
      @load_balancer_listener      = FactoryGirl.create("load_balancer_listener_#{t}".to_sym,
                                                        :load_balancer => deployed_load_balancer)
      @load_balancer_pool_member   = FactoryGirl.create("load_balancer_pool_member_#{t}".to_sym,
                                                        :vm => vm_1)
      @load_balancer_pool_member_1 = FactoryGirl.create("load_balancer_pool_member_#{t}".to_sym,
                                                        :vm => vm_2)
      @load_balancer_health_check  = FactoryGirl.create("load_balancer_health_check_#{t}".to_sym)

      FactoryGirl.create("load_balancer_listener_pool".to_sym,
                         :load_balancer_pool     => @load_balancer_pool,
                         :load_balancer_listener => @load_balancer_listener)
      FactoryGirl.create("load_balancer_pool_member_pool".to_sym,
                         :load_balancer_pool        => @load_balancer_pool,
                         :load_balancer_pool_member => @load_balancer_pool_member)
      FactoryGirl.create("load_balancer_pool_member_pool".to_sym,
                         :load_balancer_pool        => @load_balancer_pool,
                         :load_balancer_pool_member => @load_balancer_pool_member_1)
      FactoryGirl.create("load_balancer_health_check_member".to_sym,
                         :load_balancer_health_check => @load_balancer_health_check,
                         :load_balancer_pool_member  => @load_balancer_pool_member)

      expect(service_with_deployed_load_balancer.all_vms.map(&:id)).to match_array([vm_1, vm_2].map(&:id))
      expect(service_with_deployed_load_balancer.direct_vms.map(&:id)).to match_array([vm_1, vm_2].map(&:id))
      expect(service_with_deployed_load_balancer.indirect_vms.map(&:id)).to match_array([].map(&:id))
      expect(service_with_deployed_load_balancer.vms.map(&:id)).to match_array([vm_1, vm_2].map(&:id))
    end

    it 'returns no vm if no load_balancer is deployed' do
      expect(service.all_vms).to be_empty
      expect(service.direct_vms).to be_empty
      expect(service.indirect_vms).to be_empty
      expect(service.vms).to be_empty
    end
  end
end
