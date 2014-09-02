require "spec_helper"

describe "Quota Validation" do

  before(:each) do
    @group         = FactoryGirl.create(:miq_group, :description => 'Test Group')
    @fred          = FactoryGirl.create(:user, :name => 'Fred Flintstone', :userid => 'fred', :email => 'tester@miq.com', :miq_groups => [@group])
    @approver_role = FactoryGirl.create(:ui_task_set_approver)
    @vm_template   = FactoryGirl.create(:template_vmware, :name => "template1")
    @vm1           = FactoryGirl.create(:vm_vmware)
    @vm1.miq_group = @group
  end

  let(:ws) { MiqAeEngine.instantiate("/Infrastructure/VM/Provisioning/StateMachines/ProvisionRequestQuotaVerification/Default?MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}&MiqRequest::miq_request=#{@miq_provision_request.id}&max_group_cpu=#{@max_group_cpu}") }

  context "validate vcpus quota limit, using number of cpus" do
    before do
      prov_options = {:number_of_vms => 1, :owner_email => 'tester@miq.com', :vm_memory => ['1024', '1024'], :number_of_sockets => [2, '2'], :cores_per_socket => [2, '2'], :number_of_cpus => [2, '2']}
      @miq_provision_request    = FactoryGirl.create(:miq_provision_request, :userid => @fred.userid, :src_vm_id => @vm_template.id, :options => prov_options)
      @miq_request = @miq_provision_request.create_request
      @miq_request.save!
    end

    it "quota failure" do
      @max_group_cpu = 1

      root = ws.root
      root['ae_result'].should == 'error'
      root['ae_state'].should  == 'ValidateQuotas'
      root['reason'].should    == "Request denied due to the following quota limits:(Group Allocated vCPUs 0 + Requested 2 > Quota 1) "
    end

    it "quota success" do
      @max_group_cpu = 2

      ws.root['ae_result'].should == 'ok'
    end
  end

  context "validate vcpus quota limit, using cores_per_socket and number_of_sockets" do
    before do
      prov_options = {:number_of_vms => 1, :owner_email => 'tester@miq.com', :vm_memory => ['1024', '1024'], :number_of_sockets => [2, '2'], :cores_per_socket => [2, '2']}
      @miq_provision_request    = FactoryGirl.create(:miq_provision_request, :userid => @fred.userid, :src_vm_id => @vm_template.id, :options => prov_options)
      @miq_request = @miq_provision_request.create_request
      @miq_request.save!
    end

    it "quota failure" do
      @max_group_cpu = 1

      root = ws.root
      root['ae_result'].should == 'error'
      root['ae_state'].should  == 'ValidateQuotas'
      root['reason'].should    == "Request denied due to the following quota limits:(Group Allocated vCPUs 0 + Requested 4 > Quota 1) "
    end

    it "quota success" do
      @max_group_cpu = 4

      ws.root['ae_result'].should == 'ok'
    end
  end

end
