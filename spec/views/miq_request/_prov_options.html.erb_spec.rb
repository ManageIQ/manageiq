describe 'miq_request/_prov_options.html.haml' do
  context 'requester dropdown select box is visible' do
    before(:each) do
      EvmSpecHelper.local_miq_server
      stub_server_configuration(:server => {}, :session => {})

      # Create users
      @admin    = FactoryGirl.create(:user, :role => "super_administrator")
      @vm_user  = FactoryGirl.create(:user, :role => "vm_user")
      @desktop  = FactoryGirl.create(:user, :role => "desktop")
      @approver = FactoryGirl.create(:user, :role => "approver")
      @users = [@admin, @vm_user, @desktop, @approver]

      # Create requests
      FactoryGirl.create(:vm_migrate_request, :requester => @admin)
      FactoryGirl.create(:vm_migrate_request, :requester => @vm_user)
      FactoryGirl.create(:vm_migrate_request, :requester => @desktop)
      FactoryGirl.create(:vm_migrate_request, :requester => @approver)

      # Set instance variables
      sb = {:prov_options => {
        :resource_type       => :MiqProvisionRequest,
        :MiqProvisionRequest => {
          :users  => {
            @admin.id    => @admin.name,
            @vm_user.id  => @vm_user.name,
            @desktop.id  => @desktop.name,
            @approver.id => @approver.name
          },
          :states => {:pending_approval => 'Pending'},
          :types  => {:template => 'VM Provision'}
        }
      }}
      sb[:def_prov_options] = sb[:prov_options]
      sb[:def_prov_options][:MiqProvisionRequest][:applied_states] = %w(pending_approval)
      view.instance_variable_set(:@sb, sb)
    end

    it 'for admin' do
      login_as @admin
      render
      @users.each do |u|
        expect(rendered).to have_selector('select#user_choice option', :text => u.name)
      end
    end

    it 'for approver' do
      login_as @approver
      render
      @users.each do |u|
        expect(rendered).to have_selector('select#user_choice option', :text => u.name)
      end
    end
  end

  context 'requester dropdown select box is not visible' do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      stub_settings(:server => {}, :session => {})
    end

    it 'for desktop' do
      desktop = FactoryGirl.create(:user, :role => "desktop")
      FactoryGirl.create(:vm_migrate_request, :requester => desktop)

      sb = {:prov_options => {
        :resource_type       => :MiqProvisionRequest,
        :MiqProvisionRequest => {
          :users  => {
            desktop.id  => desktop.name,
          },
          :states => {:pending_approval => 'Pending'},
          :types  => {:template => 'VM Provision'}
        }
      }}
      sb[:def_prov_options] = sb[:prov_options]
      sb[:def_prov_options][:MiqProvisionRequest][:applied_states] = %w(pending_approval)
      view.instance_variable_set(:@sb, sb)

      login_as desktop
      render
      expect(rendered).to have_selector('.requester', :text => desktop.name)
      expect(rendered).not_to have_selector('select#user_choice option')
    end

    it 'for vm_user' do
      vm_user = FactoryGirl.create(:user, :role => "vm_user")
      FactoryGirl.create(:vm_migrate_request, :requester => vm_user)

      # Set instance variables
      sb = {:prov_options => {
        :resource_type       => :MiqProvisionRequest,
        :MiqProvisionRequest => {
          :users  => {
            vm_user.id  => vm_user.name,
          },
          :states => {:pending_approval => 'Pending'},
          :types  => {:template         => 'VM Provision'}
        }
      }}
      sb[:def_prov_options] = sb[:prov_options]
      sb[:def_prov_options][:MiqProvisionRequest][:applied_states] = %w(pending_approval)
      view.instance_variable_set(:@sb, sb)

      login_as vm_user
      render
      expect(rendered).to have_selector('.requester', :text => vm_user.name)
      expect(rendered).not_to have_selector('select#user_choice option')
    end
  end
end
