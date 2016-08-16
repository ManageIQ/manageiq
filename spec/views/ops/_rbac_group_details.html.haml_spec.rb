describe 'ops/_rbac_group_details.html.haml' do
  context 'add new group' do
    before(:each) do
      miq_server = FactoryGirl.create(:miq_server)
      edit = {:new                 => {:description => ''},
              :key                 => "settings_authentication_edit__#{miq_server.id}",
              :ldap_groups_by_user => [],
              :roles               => %w(fred wilma),
              :projects_tenants    => [["projects", %w(foo bar)]]
      }
      view.instance_variable_set(:@edit, edit)
      @group = FactoryGirl.create(:miq_group, :description => 'flintstones')
      allow(view).to receive(:current_tenant).and_return(Tenant.seed)
      allow(view).to receive(:session).and_return(:assigned_filters => [])
    end

    it 'should show "Look up groups" checkbox and label for auth mode ldap' do
      stub_server_configuration(:authentication => { :mode => 'ldap' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).to have_selector('input#lookup')
      expect(rendered).to include('Look up LDAP Groups')
    end

    it 'should show "Look up groups" checkbox and label for auth mode ldaps' do
      stub_server_configuration(:authentication => { :mode => 'ldaps' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).to have_selector('input#lookup')
      expect(rendered).to include('Look up LDAPS Groups')
    end

    it 'should show "Look up groups" checkbox and label for auth mode amazon' do
      stub_server_configuration(:authentication => { :mode => 'amazon' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).to have_selector('input#lookup')
      expect(rendered).to include('Look up Amazon Groups')
    end

    it 'should show "Look up groups" checkbox and label for auth mode httpd' do
      stub_server_configuration(:authentication => { :mode => 'httpd' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).to have_selector('input#lookup')
      expect(rendered).to include('Look up External Authentication Groups')
    end

    it 'should not show "Look up groups" checkbox and label for auth mode database' do
      stub_server_configuration(:authentication => { :mode => 'database' })
      render :partial => 'ops/rbac_group_details'
      expect(rendered).not_to have_selector('input#lookup')
      expect(rendered).not_to include('Look up External Authentication Groups')
    end
  end
end
