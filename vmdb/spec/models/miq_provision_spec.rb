require "spec_helper"

describe MiqProvision do
  context "A new provision request," do
    before(:each) do
      @os = OperatingSystem.new(:product_name => 'Microsoft Windows')
      User.any_instance.stub(:role).and_return("admin")
      @user     = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @approver = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
      UiTaskSet.stub(:find_by_name).and_return(@approver)
      @target_vm_name = 'clone test'
      @options = {
        :pass          => 1,
        :vm_name       => @target_vm_name,
        :number_of_vms => 1,
        :cpu_limit     => -1,
        :cpu_reserve   => 0
      }
    end

    context "with VMware infrastructure" do
      before(:each) do
        @ems         = FactoryGirl.create(:ems_vmware_with_authentication)
        @vm_template = FactoryGirl.create(:template_vmware, :name => "template1", :ext_management_system => @ems, :operating_system => @os, :cpu_limit => -1, :cpu_reserve => 0)
        @vm          = FactoryGirl.create(:vm_vmware, :name => "vm1", :location => "abc/def.vmx")
      end

      context "with a valid userid and source vm," do
        before(:each) do
          @pr = FactoryGirl.create(:miq_provision_request, :userid => @user.userid, :src_vm_id => @vm_template.id)
          @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
          @vm_prov = FactoryGirl.create(:miq_provision, :userid => @user.userid, :miq_request => @pr, :source => @vm_template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => @options)
        end

        it "should get values out of an arrays in the options hash" do
          @vm_prov.options[:src_vm_id].should be_kind_of(Array)
          @vm_prov.get_option(:src_vm_id).should == @vm_template.id
          @vm_prov.get_option_last(:src_vm_id).should == @vm_template.name
          @vm_prov.get_option_last(:number_of_vms).should == 1
          @vm_prov.get_option(nil, @vm_prov.options[:src_vm_id]).should == @vm_template.id
        end

        it "should return a user object" do
          user = @vm_prov.get_user
          user.should be_kind_of(User)
          user.should == @user
        end

        it "should return a description" do
          @vm_prov.class.get_description(@vm_prov, nil).should_not be_blank
        end

        it "should populate description, target_name and target_hostname" do
          @vm_prov.after_request_task_create
          @vm_prov.description.should_not be_nil
          @vm_prov.get_option(:vm_target_name).should_not be_nil
          @vm_prov.get_option(:vm_target_hostname).should_not be_nil
        end

        it "should create a valid target_name and hostname" do
          @vm_prov.after_request_task_create
          @vm_prov.get_option(:vm_target_name).should == @target_vm_name

          @vm_prov.options[:number_of_vms] = 2
          @vm_prov.after_request_task_create
          name_001 = "#{@target_vm_name}001"
          @vm_prov.get_option(:vm_target_name).should == name_001
          # Hostname cannot contain spaces or underscores, they should be replaces with (-)
          @vm_prov.get_option(:vm_target_hostname).should == name_001.gsub(/ +|_+/, "-")

          @vm_prov.options[:pass] = 2
          @vm_prov.after_request_task_create
          name_002 = "#{@target_vm_name}002"
          @vm_prov.get_option(:vm_target_name).should == name_002
          # Hostname cannot contain spaces or underscores, they should be replaces with (-)
          @vm_prov.get_option(:vm_target_hostname).should == name_002.gsub(/ +|_+/, "-")
        end

        context "when auto naming sequence exceeds the range" do
          before do
            region = MiqRegion.my_region
            region.naming_sequences.create(:name => "#{@target_vm_name}$n{3}", :source => "provisioning", :value => 998)
            region.naming_sequences.create(:name => "#{@target_vm_name}$n{4}", :source => "provisioning", :value => 10)
          end

          it "should advance to next range but based on the existing sequence number for the new range" do
            @vm_prov.options[:number_of_vms] = 2
            @vm_prov.after_request_task_create
            @vm_prov.get_option(:vm_target_name).should == "#{@target_vm_name}999"  # 3 digits

            @vm_prov.options[:pass] = 2
            @vm_prov.after_request_task_create
            @vm_prov.get_option(:vm_target_name).should == "#{@target_vm_name}0011" # 4 digits
          end
        end

        it "should create a hostname with a valid length based on the OS" do
          # Hostname lengths by platform:
          #   Linux   : 63
          #   Windows : 15
          #                                      1         2         3         4         5         6
          @vm_prov.options[:vm_name] = '123456789012345678901234567890123456789012345678901234567890123456789'
          @vm_prov.after_request_task_create
          @vm_prov.get_option(:vm_target_hostname).length.should == 15

          os_linux = OperatingSystem.new(:product_name => 'linux')
          @vm_prov.source.operating_system = os_linux
          @vm_prov.after_request_task_create
          @vm_prov.get_option(:vm_target_hostname).length.should == 63
        end

        it "should select a different IP address for multiple provisions" do
          @vm_prov.set_static_ip_address(1).should be_nil
          @vm_prov.options[:ip_addr] = '127.0.0.100'
          @vm_prov.set_static_ip_address(1)
          @vm_prov.get_option(:ip_addr).should == '127.0.0.100'
          x = @vm_prov.set_static_ip_address(2)
          @vm_prov.get_option(:ip_addr).should == '127.0.0.101'
        end

        it "should skip post-provisioning if the request is finished or in error" do
          @vm_prov.prematurely_finished?.should be_false

          init_state = @vm_prov.state
          @vm_prov.state = 'finished'
          @vm_prov.prematurely_finished?.should be_true

          @vm_prov.state = init_state
          @vm_prov.status = 'Error'
          @vm_prov.prematurely_finished?.should be_true

          @vm_prov.state = 'finished'
          @vm_prov.prematurely_finished?.should be_true
        end

        it "#my_zone" do
          @vm_prov.source.class.any_instance.should_receive(:my_zone).once
          @pr.class.any_instance.should_receive(:my_zone).never

          @vm_prov.my_zone
        end
      end
    end
  end

  context "#eligible_resources" do
    it "workflow should be called with placement_auto = false and skip_dialog_load = true" do
      prov     = FactoryGirl.build(:miq_provision)
      host     = active_record_instance_double('Host', :id => 1, :name => 'my_host')
      workflow = auto_loaded_instance_double("MiqProvisionWorkflow", :allowed_hosts => [host])

      prov.should_receive(:eligible_resource_lookup).and_return(host)

      prov.should_receive(:workflow).with do |options, flags|
        options[:placement_auto].should eq([false, 0])
        flags[:skip_dialog_load].should be_true
      end.and_return(workflow)

      prov.eligible_resources(:hosts)
    end
  end
end
