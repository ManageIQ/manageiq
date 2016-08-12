describe 'ops/_settings_add_new_group.html.haml' do
  context 'add new group' do
    before(:each) do
      @edit = nil
      let(:current_tenant) { FactoryGirl.create(:tenant, :name => 'tenant1') }
      let(:tenant_name) { 'tenant1' }
      @group = FactoryGirl.create(:miq_group, :description => 'asdf')
    end

    it 'should show group LDAP Look up groups checkbox and label' do
      stub_server_configuration(:authentication => { :mode => 'ldap' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).to have_selector('input#lookup', type='checkbox')
      expect(rendered).to include('Look up LDAP Groups')
    end

    it 'should show group LDAPS Look up groups checkbox and label' do
      stub_server_configuration(:authentication => { :mode => 'ldaps' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).to have_selector('input#lookup', type='checkbox')
      expect(rendered).to include('Look up LDAPS Groups')
    end

    it 'should show group Amazon Look up groups checkbox and label' do
      stub_server_configuration(:authentication => { :mode => 'amazon' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).to have_selector('input#lookup', type='checkbox')
      expect(rendered).to include('Look up Amazon Groups')
    end

    it 'should show group httpd Look up groups checkbox and label' do
      stub_server_configuration(:authentication => { :mode => 'httpd' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).to have_selector('input#lookup', type='checkbox')
      expect(rendered).to include('Look up External Authentication Groups')
    end

    it 'should not show group Database Look up groups checkbox and label' do
      stub_server_configuration(:authentication => { :mode => 'database' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).not_to have_selector('input#lookup', type='checkbox')
      expect(rendered).not_to include('Look up External Authentication Groups')
    end
  end
end
