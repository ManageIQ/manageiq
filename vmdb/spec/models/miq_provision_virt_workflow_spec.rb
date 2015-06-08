require "spec_helper"

describe MiqProvisionVirtWorkflow do
  let(:workflow) { FactoryGirl.create(:miq_provision_virt_workflow) }

  context "#continue_request" do
    let(:sdn)      { "SysprepDomainName" }

    before do
      workflow.stub(:validate => true)
      workflow.stub(:get_dialogs => {})
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => 123, :sysprep_enabled => 'fields', :sysprep_domain_name => sdn)
    end

    context "exit_pre_dialog" do
      it "doesn't exit when not running" do
        workflow.should_not_receive(:exit_pre_dialog)

        expect(workflow.continue_request({}, nil)).to be_true
      end

      it "exits when running" do
        workflow.instance_variable_set(:@running_pre_dialog, true)
        new_values = workflow.instance_variable_get(:@values)

        workflow.should_receive(:exit_pre_dialog).once.and_call_original

        expect(workflow.continue_request({}, nil)).to                   be_true
        expect(workflow.instance_variable_get(:@last_vm_id)).to         eq(123)
        expect(workflow.instance_variable_get(:@running_pre_dialog)).to be_false
        expect(workflow.instance_variable_get(:@tags)).to               be_nil
        expect(new_values[:forced_sysprep_enabled]).to                  eq('fields')
        expect(new_values[:forced_sysprep_domain_name]).to              eq([sdn])
        expect(new_values[:sysprep_domain_name]).to                     eq([sdn, sdn])
        expect(new_values[:vm_tags]).to                                 be_kind_of(Array)
      end
    end
  end

  context 'network selection' do
    before do
      @ems    = FactoryGirl.create(:ems_vmware)
      @host1  = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
      @src_vm = FactoryGirl.create(:vm_vmware, :host => @host1, :ems_id => @ems.id)
      Rbac.stub(:search) do |hash|
        [Array.wrap(hash[:targets])]
      end
      VmOrTemplate.any_instance.stub(:archived?).with(no_args).and_return(false)
      VmOrTemplate.any_instance.stub(:orphaned?).with(no_args).and_return(false)
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id)
      workflow.instance_variable_set(:@target_resource, nil)
    end

    context 'vlans' do
      before do
        s11 = FactoryGirl.create(:switch, :name => "A")
        s12 = FactoryGirl.create(:switch, :name => "B")
        s13 = FactoryGirl.create(:switch, :name => "C")
        @src_vm.host.switches = [s11, s12, s13]
        @lan11 = FactoryGirl.create(:lan, :name => "lan_A", :switch_id => s11.id)
        @lan12 = FactoryGirl.create(:lan, :name => "lan_B", :switch_id => s12.id)
        @lan13 = FactoryGirl.create(:lan, :name => "lan_C", :switch_id => s13.id)
      end

      it '#allowed_vlans' do
        workflow.stub(:allowed_hosts).with(no_args).and_return([workflow.host_to_hash_struct(@host1)])
        vlans = workflow.allowed_vlans(:vlans => true, :dvs => false)
        lan_keys = [@lan11.name, @lan13.name, @lan12.name]
        vlans.keys.should match_array(lan_keys)
        vlans.values.should match_array(lan_keys)
      end
    end

    context 'dvs' do
      before do
        @host1_dvs = {'pg1' => ['switch1'],  'pg2' => ['switch2']}
        @host1_dvs_hash    = {'dvs_pg1' => 'pg1 (switch1)',
                              'dvs_pg2' => 'pg2 (switch2)'}
        EmsVmware.any_instance.stub(:connect)
        workflow.stub(:get_host_dvs).with(@host1, nil).and_return(@host1_dvs)
      end

      it '#allowed_dvs single host' do
        workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id,
                                      :host_id => @host1.id)
        workflow.instance_variable_set(:@target_resource,
                                       :host    => workflow.host_to_hash_struct(@host1),
                                       :ems     => workflow.default_ci_to_hash_struct(@ems),
                                       :host_id => @host1.id)
        dvs = workflow.allowed_dvs({}, nil)
        dvs.should eql(@host1_dvs_hash)
      end

      context "#allowed_dvs" do
        before do
          @host2 = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
          @host2_dvs = {'pg1' => ['switch21'], 'pg2' => ['switch2'], 'pg3' => ['switch23']}
          workflow.stub(:get_host_dvs).with(@host2, nil).and_return(@host2_dvs)
          workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id,
                                        :placement_auto => true)

          @combined_dvs_hash = {'dvs_pg1' => 'pg1 (switch1/switch21)',
                                'dvs_pg2' => 'pg2 (switch2)',
                                'dvs_pg3' => 'pg3 (switch23)'}
        end

        it 'multiple hosts auto placement' do
          dvs = workflow.allowed_dvs({}, nil)
          dvs.should eql(@combined_dvs_hash)
        end

        it 'cached filtering' do
          # Cache the dvs for 2 hosts
          workflow.allowed_dvs({}, nil)

          workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id,
                                        :placement_auto => false)
          workflow.instance_variable_set(:@target_resource,
                                         :host    => workflow.host_to_hash_struct(@host1),
                                         :ems     => workflow.default_ci_to_hash_struct(@ems),
                                         :host_id => @host1.id)
          dvs = workflow.allowed_dvs({}, nil)
          dvs.should eql(@host1_dvs_hash)
        end
      end
    end
  end

  context "#validate_memory_reservation" do
    let(:values) { {:vm_memory => ["1024", "1024"]} }

    it "no size" do
      expect(workflow.validate_memory_reservation(nil, values, {}, {}, nil)).to be_nil
    end

    it "valid size" do
      expect(workflow.validate_memory_reservation(nil, values.merge(:memory_reserve => 1024), {}, {}, nil)).to be_nil
    end

    it "invalid size" do
      error = "Memory Reservation is larger than VM Memory"

      workflow.should_receive(:required_description).and_return("Memory")
      expect(workflow.validate_memory_reservation(nil, values.merge(:memory_reserve => 2048), {}, {}, nil)).to eq(error)
    end
  end
end
