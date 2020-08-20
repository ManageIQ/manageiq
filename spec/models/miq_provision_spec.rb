RSpec.describe MiqProvision do
  context "A new provision request," do
    before do
      @os = OperatingSystem.new(:product_name => 'Microsoft Windows')
      @admin = FactoryBot.create(:user_with_group, :role => "admin")
      @target_vm_name = 'clone test'
      @options = {
        :pass          => 1,
        :vm_name       => @target_vm_name,
        :number_of_vms => 1,
        :cpu_limit     => -1,
        :cpu_reserve   => 0
      }
    end

    let(:miq_region) { MiqRegion.create }

    context "with VMware infrastructure" do
      before do
        @ems         = FactoryBot.create(:ems_vmware_with_authentication)
        @vm_template = FactoryBot.create(:template_vmware, :name => "template1", :ext_management_system => @ems, :operating_system => @os, :cpu_limit => -1, :cpu_reserve => 0)
        @vm          = FactoryBot.create(:vm_vmware, :name => "vm1", :location => "abc/def.vmx")
      end

      context "with a valid userid and source vm," do
        before do
          @pr = FactoryBot.create(:miq_provision_request, :requester => @admin, :src_vm_id => @vm_template.id)
          @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
          @vm_prov = FactoryBot.create(:miq_provision, :userid => @admin.userid, :miq_request => @pr, :source => @vm_template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => @options)
        end

        it "should get values out of an arrays in the options hash" do
          expect(@vm_prov.options[:src_vm_id]).to be_kind_of(Array)
          expect(@vm_prov.get_option(:src_vm_id)).to eq(@vm_template.id)
          expect(@vm_prov.get_option_last(:src_vm_id)).to eq(@vm_template.name)
          expect(@vm_prov.get_option_last(:number_of_vms)).to eq(1)
          expect(@vm_prov.get_option(nil, @vm_prov.options[:src_vm_id])).to eq(@vm_template.id)
        end

        it "should return a user object" do
          user = @vm_prov.get_user
          expect(user).to be_kind_of(User)
          expect(user).to eq(@admin)
        end

        it "should return a description" do
          expect(@vm_prov.class.get_description(@vm_prov, nil)).not_to be_blank
        end

        it "should populate description, target_name and target_hostname" do
          allow(@vm_prov).to receive(:get_next_vm_name).and_return("test_vm")
          @vm_prov.after_request_task_create
          expect(@vm_prov.description).not_to be_nil
          expect(@vm_prov.get_option(:vm_target_name)).not_to be_nil
          expect(@vm_prov.get_option(:vm_target_hostname)).not_to be_nil
        end

        it "should create a valid target_name and hostname" do
          expect(MiqRegion).to receive(:my_region).and_return(miq_region).twice
          ae_workspace = double("ae_workspace")
          expect(ae_workspace).to receive(:root).and_return(@target_vm_name)
          expect(MiqAeEngine).to receive(:resolve_automation_object).and_return(ae_workspace).exactly(3).times

          @vm_prov.after_request_task_create
          expect(@vm_prov.get_option(:vm_target_name)).to eq(@target_vm_name)

          expect(ae_workspace).to receive(:root).and_return("#{@target_vm_name}$n{3}").twice
          @vm_prov.options[:number_of_vms] = 2
          @vm_prov.after_request_task_create
          name_001 = "#{@target_vm_name}001"
          expect(@vm_prov.get_option(:vm_target_name)).to eq(name_001)
          # Hostname cannot contain spaces or underscores, they should be replaces with (-)
          expect(@vm_prov.get_option(:vm_target_hostname)).to eq(name_001.gsub(/ +|_+/, "-"))

          @vm_prov.options[:pass] = 2
          @vm_prov.after_request_task_create
          name_002 = "#{@target_vm_name}002"
          expect(@vm_prov.get_option(:vm_target_name)).to eq(name_002)
          # Hostname cannot contain spaces or underscores, they should be replaces with (-)
          expect(@vm_prov.get_option(:vm_target_hostname)).to eq(name_002.gsub(/ +|_+/, "-"))
        end

        context "#update_vm_name" do
          it "does not modify a fully resolved vm_name" do
            @vm_prov.update_vm_name(@target_vm_name)
            expect(@vm_prov.get_option(:vm_target_name)).to eq(@target_vm_name)
          end

          it "Enumerates vm_name that contains the naming sequence characters" do
            expect(MiqRegion).to receive(:my_region).and_return(miq_region)

            @vm_prov.update_vm_name("#{@target_vm_name}$n{3}")
            expect(@vm_prov.get_option(:vm_target_name)).to eq("#{@target_vm_name}001")
          end

          it "Updates the request description with only name parameter passed" do
            expect(@pr).to receive(:update_description_from_tasks).and_call_original

            @vm_prov.update_vm_name(@target_vm_name)

            expect(@vm_prov.description).to eq("Provision from [template1] to [clone test]")
            expect(@pr.description).to eq(@vm_prov.description)
          end

          it "Does not update the request description when `update_request` parameter is false" do
            expect(@pr).not_to receive(:update_description_from_tasks)

            @vm_prov.update_vm_name(@target_vm_name, :update_request => false)
          end

          it "When task is part of a ServiceTemplateProvisionRequest the description should not update" do
            request_descripton = "Service Name Test"
            service_provision_request = FactoryBot.create(:service_template_provision_request, :description => request_descripton)
            @vm_prov.update(:miq_request_id => service_provision_request.id)

            expect(service_provision_request).not_to receive(:update)
            @vm_prov.update_vm_name(@target_vm_name, :update_request => true)

            expect(service_provision_request.description).to eq(request_descripton)
          end
        end

        context "when auto naming sequence exceeds the range" do
          before do
            expect(MiqRegion).to receive(:my_region).exactly(3).times.and_return(miq_region)
            miq_region.naming_sequences.create(:name => "#{@target_vm_name}$n{3}", :source => "provisioning", :value => 998)
            miq_region.naming_sequences.create(:name => "#{@target_vm_name}$n{4}", :source => "provisioning", :value => 10)
          end

          it "should advance to next range but based on the existing sequence number for the new range" do
            ae_workspace = double("ae_workspace")
            expect(ae_workspace).to receive(:root).and_return("#{@target_vm_name}$n{3}").twice
            expect(MiqAeEngine).to receive(:resolve_automation_object).and_return(ae_workspace).twice

            @vm_prov.options[:number_of_vms] = 2
            @vm_prov.after_request_task_create
            expect(@vm_prov.get_option(:vm_target_name)).to eq("#{@target_vm_name}999")  # 3 digits

            @vm_prov.options[:pass] = 2
            @vm_prov.after_request_task_create
            expect(@vm_prov.get_option(:vm_target_name)).to eq("#{@target_vm_name}0011") # 4 digits
          end
        end

        it "should create a hostname with a valid length based on the OS" do
          # Hostname lengths by platform:
          #   Linux   : 63
          #   Windows : 15
          #                        1         2         3         4         5         6
          long_vm_name = '123456789012345678901234567890123456789012345678901234567890123456789'
          expect(@vm_prov).to receive(:get_next_vm_name).and_return(long_vm_name).twice
          @vm_prov.after_request_task_create
          expect(@vm_prov.get_option(:vm_target_hostname).length).to eq(15)

          os_linux = OperatingSystem.new(:product_name => 'linux')
          @vm_prov.source.operating_system = os_linux
          @vm_prov.after_request_task_create
          expect(@vm_prov.get_option(:vm_target_hostname).length).to eq(63)
        end

        it "should select a different IP address for multiple provisions" do
          expect(@vm_prov.set_static_ip_address(1)).to be_nil
          @vm_prov.options[:ip_addr] = '127.0.0.100'
          @vm_prov.set_static_ip_address(1)
          expect(@vm_prov.get_option(:ip_addr)).to eq('127.0.0.100')
          @vm_prov.set_static_ip_address(2)
          expect(@vm_prov.get_option(:ip_addr)).to eq('127.0.0.101')
        end

        it "should skip post-provisioning if the request is finished or in error" do
          expect(@vm_prov.prematurely_finished?).to be_falsey

          init_state = @vm_prov.state
          @vm_prov.state = 'finished'
          expect(@vm_prov.prematurely_finished?).to be_truthy

          @vm_prov.state = init_state
          @vm_prov.status = 'Error'
          expect(@vm_prov.prematurely_finished?).to be_truthy

          @vm_prov.state = 'finished'
          expect(@vm_prov.prematurely_finished?).to be_truthy
        end

        it "#my_zone" do
          expect_any_instance_of(@vm_prov.source.class).to receive(:my_zone).once
          expect_any_instance_of(@pr.class).to receive(:my_zone).never

          @vm_prov.my_zone
        end

        it "#execute_queue" do
          tracking_label = "r#{@pr.id}_miq_provision_#{@vm_prov.id}"
          miq_callback = {
            :class_name  => 'MiqProvision',
            :instance_id => @vm_prov.id,
            :method_name => :execute_callback
          }
          allow(@pr).to receive(:approved?).and_return(true)
          expect(MiqQueue).to receive(:put).with(
            :class_name     => 'MiqProvision',
            :instance_id    => @vm_prov.id,
            :method_name    => 'execute',
            :role           => 'ems_operations',
            :tracking_label => tracking_label,
            :msg_timeout    => MiqQueue::TIMEOUT,
            :queue_name     => @vm_prov.my_queue_name,
            :zone           => @vm_prov.my_zone,
            :deliver_on     => nil,
            :miq_callback   => miq_callback
          )
          @vm_prov.execute_queue
        end
      end
    end
  end

  context "#eligible_resources" do
    it "workflow should be called with placement_auto = false and skip_dialog_load = true" do
      prov     = FactoryBot.build(:miq_provision)
      host     = double('Host', :id => 1, :name => 'my_host')
      workflow = double("MiqProvisionWorkflow", :allowed_hosts => [host])

      expect(prov).to receive(:eligible_resource_lookup).and_return(host)

      expect(prov).to receive(:workflow) { |options, flags|
        expect(options[:placement_auto]).to eq([false, 0])
        expect(flags[:skip_dialog_load]).to be_truthy
      }.and_yield(workflow).and_return(workflow)

      prov.eligible_resources(:hosts)
    end
  end

  describe "#placement_auto" do
    let(:miq_provision) { FactoryBot.build(:miq_provision, :options => {:placement_auto => placement_option}) }

    context "when option[:placement_auto] is true" do
      let(:placement_option) { [true, 1] }

      it "without force_placement_auto" do
        expect(miq_provision.placement_auto).to eq(true)
      end

      it "with force_placement_auto set to false" do
        miq_provision.options[:force_placement_auto] = false
        expect(miq_provision.placement_auto).to eq(true)
      end

      it "with force_placement_auto set to true" do
        miq_provision.options[:force_placement_auto] = true
        expect(miq_provision.placement_auto).to eq(true)
      end
    end

    context "when option[:placement_auto] is false" do
      let(:placement_option) { [false, 0] }

      it "without force_placement_auto" do
        expect(miq_provision.placement_auto).to eq(false)
      end

      it "with force_placement_auto set to false" do
        miq_provision.options[:force_placement_auto] = false
        expect(miq_provision.placement_auto).to eq(false)
      end

      it "with force_placement_auto set to true" do
        miq_provision.options[:force_placement_auto] = true
        expect(miq_provision.placement_auto).to eq(true)
      end
    end
  end
end
