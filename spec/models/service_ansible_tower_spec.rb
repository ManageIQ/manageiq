describe ServiceAnsibleTower do
  let(:template_by_dialog) { FactoryGirl.create(:configuration_script) }
  let(:template_by_setter) { FactoryGirl.create(:configuration_script) }

  let(:dialog_options) do
    {
      'dialog_job_template'                   => template_by_dialog.id,
      'dialog_limit'                          => 'myhost',
      'dialog_param_InstanceType'             => 'cg1.4xlarge',
      'password::dialog_param_DBRootPassword' => 'v2:{c2XR8/Yl1CS0phoOVMNU9w==}'
    }
  end

  let(:parsed_job_options) do
    {
      :limit      => 'myhost',
      :extra_vars => {'InstanceType' => 'cg1.4xlarge', 'DBRootPassword' => 'admin'}
    }
  end

  let(:service) do
    FactoryGirl.create(:service_ansible_tower,
                       :evm_owner => FactoryGirl.create(:user),
                       :miq_group => FactoryGirl.create(:miq_group))
  end

  let(:service_with_dialog_options) do
    service.options = {:dialog => dialog_options}
    service
  end

  let(:service_mix_dialog_setter) do
    service.job_template = template_by_setter
    service.options = {:dialog => dialog_options}
    service
  end

  describe "#job_options" do
    it "gets job options set by dialog" do
      expect(service_with_dialog_options.job_options).to include(parsed_job_options)
    end

    it "gets jobs options from overridden values" do
      new_options = {"any_key" => "any_value"}
      service_with_dialog_options.job_options = new_options
      expect(service_with_dialog_options.job_options).to eq(new_options)
    end

    it "encrypts password when saves to DB" do
      new_options = {:extra_vars => {"my_password" => "secret"}}
      service_with_dialog_options.job_options = new_options
      expect(service_with_dialog_options.options[:create_options][:extra_vars]["my_password"]).to eq(MiqPassword.encrypt("secret"))
    end

    it "prefers the job template set by dialog" do
      expect(service_mix_dialog_setter.job_template).to eq(template_by_setter)
      service_mix_dialog_setter.job_options
      expect(service_mix_dialog_setter.job_template).to eq(template_by_dialog)
    end
  end

  describe '#launch_job' do
    it 'launches a job through ansible tower provider' do
      allow(ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job).to receive(:raw_create_stack) do |template, opts|
        expect(template).to be_kind_of ConfigurationScript
        expect(opts).to have_key(:limit)
        expect(opts).to have_key(:extra_vars)
      end.and_return(double(:raw_job, :id => 1, :status => "completed", :extra_vars_hash => {'var_name' => 'var_val'}))

      job_done = service_mix_dialog_setter.launch_job
      expect(job_done).to have_attributes(:ems_ref => "1", :status => "completed")
      expect(job_done.parameters[0]).to have_attributes(:name => 'var_name', :value => 'var_val', :ems_ref => '1_var_name')
    end

    it 'always saves options even when the manager fails to create a stack' do
      provision_error = MiqException::MiqOrchestrationProvisionError
      allow_any_instance_of(ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job).to receive(:stack_create).and_raise(provision_error, 'test failure')

      expect(service_mix_dialog_setter).to receive(:save_launch_options)
      expect { service_mix_dialog_setter.launch_job }.to raise_error(provision_error)
    end
  end
end
