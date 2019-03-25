describe MiqProvision::Naming do
  let(:miq_region) { MiqRegion.create }

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

  context "when auto naming sequence exceeds the range" do
    before do
      @ems         = FactoryBot.create(:ems_vmware_with_authentication)
      @vm_template = FactoryBot.create(:template_vmware, :name => "template1", :ext_management_system => @ems, :operating_system => @os, :cpu_limit => -1, :cpu_reserve => 0)
      @vm          = FactoryBot.create(:vm_vmware, :name => "vm1", :location => "abc/def.vmx")

      @pr = FactoryBot.create(:miq_provision_request, :requester => @admin, :src_vm_id => @vm_template.id)
      @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
      @vm_prov = FactoryBot.create(:miq_provision, :userid => @admin.userid, :miq_request => @pr, :source => @vm_template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => @options)

      miq_region.naming_sequences.create(:name => "#{@target_vm_name}$n{3}", :source => "provisioning", :value => 998)
      miq_region.naming_sequences.create(:name => "#{@target_vm_name}$n{4}", :source => "provisioning", :value => 10)
    end

    it "should advance to next range but based on the existing sequence number for the new range" do
      expect(MiqRegion).to receive(:my_region).exactly(3).times.and_return(miq_region)

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

    it "should advance to next range but based on the existing sequence number for the new range" do
      expect(MiqRegion).to receive(:my_region).exactly(2).times.and_return(miq_region)

      ae_workspace = double("ae_workspace")
      expect(ae_workspace).to receive(:root).and_return("#{@target_vm_name}$n{3, -1}").twice
      expect(MiqAeEngine).to receive(:resolve_automation_object).and_return(ae_workspace).twice

      @vm_prov.options[:number_of_vms] = 2
      @vm_prov.after_request_task_create
      expect(@vm_prov.get_option(:vm_target_name)).to eq("#{@target_vm_name}999")  # 3 digits

      @vm_prov.options[:pass] = 2
      @vm_prov.after_request_task_create
      expect(@vm_prov.get_option(:vm_target_name)).to eq("#{@target_vm_name}1000") # 4 digits
    end
  end
end
