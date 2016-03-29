describe MiqProvisionVirtWorkflow do
  let(:workflow) { FactoryGirl.create(:miq_provision_virt_workflow) }

  context "#continue_request" do
    let(:sdn) { 'SysprepDomainName' }

    before do
      allow(workflow).to receive_messages(:validate => true)
      allow(workflow).to receive_messages(:get_dialogs => {})
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => 123, :sysprep_enabled => 'fields',
                                     :sysprep_domain_name => sdn)
    end

    context "exit_pre_dialog" do
      it "doesn't exit when not running" do
        expect(workflow).not_to receive(:exit_pre_dialog)

        expect(workflow.continue_request({})).to be_truthy
      end

      it "exits when running" do
        workflow.instance_variable_set(:@running_pre_dialog, true)
        new_values = workflow.instance_variable_get(:@values)

        expect(workflow).to receive(:exit_pre_dialog).once.and_call_original

        expect(workflow.continue_request({})).to                        be_truthy
        expect(workflow.instance_variable_get(:@last_vm_id)).to         eq(123)
        expect(workflow.instance_variable_get(:@running_pre_dialog)).to be_falsey
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
      allow(Rbac).to receive(:search) do |hash|
        [Array.wrap(hash[:targets])]
      end
      allow_any_instance_of(VmOrTemplate).to receive(:archived?).with(no_args).and_return(false)
      allow_any_instance_of(VmOrTemplate).to receive(:orphaned?).with(no_args).and_return(false)
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
        allow(workflow).to receive(:allowed_hosts).with(no_args).and_return([workflow.host_to_hash_struct(@host1)])
        vlans = workflow.allowed_vlans(:vlans => true, :dvs => false)
        lan_keys = [@lan11.name, @lan13.name, @lan12.name]
        expect(vlans.keys).to match_array(lan_keys)
        expect(vlans.values).to match_array(lan_keys)
      end
    end
  end

  context "#validate email formatting" do
    context "with specific format regex" do
      let(:regex) { {:required_regex => %r{\A[\w!#$\%&'*+/=?`\{|\}~^-]+(?:\.[\w!#$\%&'*+/=?`\{|\}~^-]+)*@(?:[A-Z0-9-]+\.)+[A-Z]{2,6}\Z}i} }
      let(:value_email) { 'n@test.com' }
      let(:value_no_email) { 'n' }

      it "matches a valid email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, value_email)).to be_nil
      end

      it "returns a formatting error message with a bad email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, value_no_email)).to eq "'/' must be correctly formatted"
      end

      it "returns an email required error with a blank email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, '')).to eq "'/' is required"
      end
    end

    context "with a match anything regex" do
      let(:regex) { {:required_regex => '.'} }
      let(:value_email) { 'n@test.com' }
      let(:value_no_email) { 'n' }

      it "matches a valid email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, value_email)).to be_nil
      end

      it "matches a bad email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, value_no_email)).to be_nil
      end

      it "returns an email required error with a blank email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, '')).to eq "'/' is required"
      end
    end
  end

  context "#update_field_visibility_pxe_iso" do
    let(:show_hide_iso_pxe) { {:hide => [], :edit => []} }
    describe "supports iso" do
      before do
        allow(workflow).to receive(:supports_iso?).and_return(true)
        allow(workflow).to receive(:supports_pxe?).and_return(false)
      end

      it "sets iso_image_id as a validated key" do
        workflow.update_field_visibility_pxe_iso(show_hide_iso_pxe)
        expect(show_hide_iso_pxe[:edit]).to eq [:iso_image_id]
        expect(show_hide_iso_pxe[:edit]).to_not eq [:pxe_image_id, :pxe_server_id]
        expect(show_hide_iso_pxe[:hide]).to_not eq [:iso_image_id]
        expect(show_hide_iso_pxe[:hide]).to eq [:pxe_image_id, :pxe_server_id]
      end
    end

    describe "supports pxe" do
      before do
        allow(workflow).to receive(:supports_iso?).and_return(false)
        allow(workflow).to receive(:supports_pxe?).and_return(true)
      end

      it "sets pxe_server_id and pxe_image_id as validated keys" do
        workflow.update_field_visibility_pxe_iso(show_hide_iso_pxe)
        expect(show_hide_iso_pxe[:edit]).to_not eq [:iso_image_id]
        expect(show_hide_iso_pxe[:edit]).to eq [:pxe_image_id, :pxe_server_id]
        expect(show_hide_iso_pxe[:hide]).to eq [:iso_image_id]
        expect(show_hide_iso_pxe[:hide]).to_not eq [:pxe_image_id, :pxe_server_id]
      end
    end
  end

  context "#validate_memory_reservation" do
    let(:values) { {:vm_memory => %w(1024 1024)} }

    it "no size" do
      expect(workflow.validate_memory_reservation(nil, values, {}, {}, nil)).to be_nil
    end

    it "valid size" do
      expect(workflow.validate_memory_reservation(nil, values.merge(:memory_reserve => 1024), {}, {}, nil)).to be_nil
    end

    it "invalid size" do
      error = "Memory Reservation is larger than VM Memory"

      expect(workflow).to receive(:required_description).and_return("Memory")
      expect(workflow.validate_memory_reservation(nil, values.merge(:memory_reserve => 2048), {}, {}, nil)).to eq(error)
    end
  end

  context "#allowed_template_condition" do
    it "without a provider model defined" do
      expect(workflow.allowed_template_condition).to eq(["vms.template = ? AND vms.ems_id IS NOT NULL", true])
    end

    it "with a provider model defined" do
      ems = FactoryGirl.create(:ems_vmware)
      expect(workflow.class).to receive(:provider_model).once.and_return(ems.class)

      expect(workflow.allowed_template_condition).to eq(["vms.template = ? AND vms.ems_id in (?)", true, [ems.id]])
    end
  end
end
