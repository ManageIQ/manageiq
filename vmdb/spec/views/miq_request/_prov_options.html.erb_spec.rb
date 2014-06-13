require "spec_helper"
include ApplicationHelper

describe 'miq_request/_prov_options.html.erb' do
  context 'requester dropdown select box is visible' do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      view.stub(:get_vmdb_config).and_return({:server => {}, :session => {}})
      MiqRegion.seed

      # Create roles/groups
      @approver_role = UiTaskSet.create(:name => 'approver', :description => 'Approver')
      role1   = FactoryGirl.create(:miq_user_role, :name    => 'EvmRole-super_administrator')
      role2   = FactoryGirl.create(:miq_user_role, :name    => 'EvmRole-vm_user')
      role3   = FactoryGirl.create(:miq_user_role, :name    => 'EvmRole-desktop')
      role4   = FactoryGirl.create(:miq_user_role, :name    => 'EvmRole-approver')
      @group1 = FactoryGirl.create(:miq_group, :description => 'EvmGroup-super_administrator', :miq_user_role => role1)
      @group2 = FactoryGirl.create(:miq_group, :description => 'EvmGroup-vm_user',  :miq_user_role => role2)
      @group3 = FactoryGirl.create(:miq_group, :description => 'EvmGroup-desktop',  :miq_user_role => role3)
      @group4 = FactoryGirl.create(:miq_group, :description => 'EvmGroup-approver', :miq_user_role => role4)

      # Create users
      @admin    = FactoryGirl.create(:user, :name => 'Admin',    :userid => 'admin',    :miq_groups => [@group1])
      @vm_user  = FactoryGirl.create(:user, :name => 'VM User',  :userid => 'vm_user',  :miq_groups => [@group2])
      @desktop  = FactoryGirl.create(:user, :name => 'Desktop',  :userid => 'desktop',  :miq_groups => [@group3])
      @approver = FactoryGirl.create(:user, :name => 'Approver', :userid => 'approver', :miq_groups => [@group4])
      @users = [@admin, @vm_user, @desktop, @approver]

      # Create requests
      FactoryGirl.create(:miq_request, :requester => @admin)
      FactoryGirl.create(:miq_request, :requester => @vm_user)
      FactoryGirl.create(:miq_request, :requester => @desktop)
      FactoryGirl.create(:miq_request, :requester => @approver)

      # Set instance variables
      sb = {:prov_options => {
          :resource_type => :MiqProvisionRequest,
          :MiqProvisionRequest => {
              :users => {
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
      User.stub(:current_user => @admin)
      render
      @users.each do |u|
        rendered.should have_selector('select#user_choice option', :text => u.name)
      end
    end

    it 'for approver' do
      User.stub(:current_user => @approver)
      render
      @users.each do |u|
        rendered.should have_selector('select#user_choice option', :text => u.name)
      end
    end
  end

  context 'requester dropdown select box is not visible' do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      view.stub(:get_vmdb_config).and_return({:server => {}, :session => {}})
      MiqRegion.seed
      @approver_role = UiTaskSet.create(:name => 'approver', :description => 'Approver')
    end

    it 'for desktop' do
      role    = FactoryGirl.create(:miq_user_role, :name    => 'EvmRole-desktop')
      group   = FactoryGirl.create(:miq_group, :description => 'EvmGroup-desktop',  :miq_user_role => role)
      desktop = FactoryGirl.create(:user, :name => 'Desktop',  :userid => 'desktop',  :miq_groups => [group])
      FactoryGirl.create(:miq_request, :requester => desktop)

      sb = {:prov_options => {
          :resource_type => :MiqProvisionRequest,
          :MiqProvisionRequest => {
              :users => {
                  desktop.id  => desktop.name,
              },
              :states => {:pending_approval => 'Pending'},
              :types  => {:template => 'VM Provision'}
          }
      }}
      sb[:def_prov_options] = sb[:prov_options]
      sb[:def_prov_options][:MiqProvisionRequest][:applied_states] = %w(pending_approval)
      view.instance_variable_set(:@sb, sb)

      User.stub(:current_user => desktop)
      render
      rendered.should have_selector('td', :text => desktop.name)
      rendered.should_not have_selector('select#user_choice option')
    end

    it 'for vm_user' do
      role    = FactoryGirl.create(:miq_user_role, :name => 'EvmRole-vm_user')
      group   = FactoryGirl.create(:miq_group, :description => 'EvmGroup-vm_user', :miq_user_role => role)
      vm_user = FactoryGirl.create(:user, :name => 'VM User', :userid => 'vm_user', :miq_groups => [group])
      FactoryGirl.create(:miq_request, :requester => vm_user)

      # Set instance variables
      sb = {:prov_options => {
          :resource_type => :MiqProvisionRequest,
          :MiqProvisionRequest => {
              :users => {
                  vm_user.id  => vm_user.name,
              },
              :states => {:pending_approval => 'Pending'},
              :types  => {:template         => 'VM Provision'}
          }
      }}
      sb[:def_prov_options] = sb[:prov_options]
      sb[:def_prov_options][:MiqProvisionRequest][:applied_states] = %w(pending_approval)
      view.instance_variable_set(:@sb, sb)

      User.stub(:current_user => vm_user)
      render
      rendered.should have_selector('td', :text => vm_user.name)
      rendered.should_not have_selector('select#user_choice option')
    end
  end
end
