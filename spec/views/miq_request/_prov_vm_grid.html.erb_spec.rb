describe 'miq_request/_prov_vm_grid.html.haml' do
  context 'check for links' do
    before(:each) do
      @vm_user = FactoryGirl.create(:user, :role => "vm_user")
      @vms = [FactoryGirl.create(:vm_vmware)]
      edit = {:req_id => "foo",
              :new => {},
              :wf => FactoryGirl.create(:miq_provision_workflow,:requester => @vm_user),
              :vm_sortcol => 'name',
              :vm_sortdir => 'ASC',
              :vm_columns => %w(name),
              :vm_headers => {"name"=>"Name"}
             }
      view.instance_variable_set(:@edit, edit)
      view.instance_variable_set(:@vms, @vms)
    end

    it 'validates links in vm grid' do
      login_as @vm_user
      render :partial => "miq_request/prov_vm_grid.html.haml", :locals => {:field_id => 'service__src_vm_id'}
      expect(rendered).to have_selector("//tr[@onclick=\"miqAjax('/miq_request/prov_field_changed/?service__src_vm_id=__VM__NONE__&id=foo');\"]")
      expect(rendered).to have_selector("//tr[@onclick=\"miqAjax('/miq_request/prov_field_changed/?service__src_vm_id=#{@vms.first.id}&id=foo');\"]")
    end
  end

  context 'prints tenant name' do
    let(:admin_user) { FactoryGirl.create(:user_with_group, :role => 'super_administrator') }
    let(:cloud_tenant) { FactoryGirl.create(:cloud_tenant, :name => 'cloud_tenant_name') }

    before do
      @vm = [FactoryGirl.create(:template_openstack, :tenant => Tenant.root_tenant)]
      allow(@vm).to receive(:name).and_return('name')
      allow(@vm).to receive(:operating_system).and_return('linux')
      allow(@vm).to receive(:platform).and_return('platform')
      allow(@vm).to receive(:cpu_total_cores).and_return('1024')
      allow(@vm).to receive(:mem_cpu).and_return('2048')
      allow(@vm).to receive(:allocated_disk_storage).and_return('4096')
      allow(@vm).to receive(:v_total_snapshots).and_return('128')
      allow(@vm).to receive(:deprecated).and_return(true)
      allow(@vm).to receive(:ext_management_system)
      allow(@vm).to receive(:cloud_tenant).and_return(cloud_tenant)

      edit = {:req_id     => 'foo',
              :new        => {},
              :wf         => FactoryGirl.create(:miq_provision_workflow, :requester => admin_user),
              :vm_sortcol => 'name',
              :vm_sortdir => 'ASC',
              :vm_columns => %w(name),
              :vm_headers => {:name          => 'Name',
                              'cloud_tenant' => true}
      }
      view.instance_variable_set(:@edit, edit)
      view.instance_variable_set(:@vm, @vm)
      view.instance_variable_set(:@_param, :tab_id => 'service')
    end

    it 'validates tenant name is printed out' do
      login_as admin_user
      render :partial => 'miq_request/prov_vm_grid.html.haml', :locals => {:field_id => 'service__src_vm_id'},
                                                               :params => { 'tab_id' => 'service' }
      expect(rendered).to have_selector('tr.selected td', :text => 'cloud_tenant_name')
    end
  end
end
