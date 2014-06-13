require "spec_helper"

describe VdiUser do
  context "with vdi_user data" do
    before(:each) do
      @user_data = [{:objectsid=>"S-1-5-21-4106323499-3255682937-2389761597-10646", :l=>"Sequim", :company=>nil, :co=>nil, :department=>nil, :displayname=>"Chuck Morey", :dn=>"CN=Chuck Morey,OU=Users,OU=Demo,DC=manageiq,DC=com", :mail=>"cmorey@manageiq.com", :facsimiletelephonenumber=>nil, :givenname=>"Chuck", :sn=>"Morey", :samaccountname=>"cmorey", :physicaldeliveryofficename=>nil, :telephonenumber=>nil, :homephone=>"201-512-1000", :mobile=>nil, :st=>"Washington", :streetaddress=>"3901 Diamond Point Rd", :title=>nil, :userprincipalname=>"cmorey@manageiq.com", :postalcode=>"98382", :ldap_domain_id => 1}]
    end

    it "#import_from_ui" do
      VdiUser.import_from_ui(@user_data)
      VdiUser.count.should == 1

      user = VdiUser.first
      user.ldap.should_not be_nil
      user.ldap.ldap_domain_id.should == 1
    end

    it "#import_from_ui with extra fields" do
      # Extra columns should be ignored during import
      @user_data[0][:not_a_column] = "Test"
      VdiUser.import_from_ui(@user_data)

      user = VdiUser.first
      user.ldap.should_not be_nil
    end

    it "#user_name_from_ldap" do
      VdiUser.import_from_ui(@user_data)
      user = VdiUser.first
      user.name.should == "manageiq.com\\cmorey"
    end

    it "#user_name_from_ldap without upn" do
      @user_data.first[:userprincipalname] = nil
      VdiUser.import_from_ui(@user_data)
      user = VdiUser.first
      user.name.should == "cmorey"

      @user_data.first[:userprincipalname] = ""
      VdiUser.import_from_ui(@user_data)
      user = VdiUser.first
      user.name.should == "cmorey"
    end


    context "with vdi_user" do
      before(:each) do
        VdiUser.import_from_ui(@user_data)
      end

      it "#delete_users" do
        VdiUser.count.should == 1
        LdapUser.count.should == 1

        task = MiqTask.create
        VdiUser.delete_users([VdiUser.first.id], task.id)
        VdiUser.count.should == 0
        LdapUser.count.should == 0
      end

      it "#delete_users with desktop association" do
        VdiUser.count.should  == 1
        vdi_user = VdiUser.first

        vdi_user.vdi_desktops << VdiDesktop.create

        task = MiqTask.create
        VdiUser.delete_users([VdiUser.first.id], task.id)
        VdiUser.count.should  == 1

        results = task.task_results
        results[:assigned].should == 1
        results[:error_msgs].length.should == 1
      end

      it "#delete_users with desktop pool association" do
        VdiUser.count.should  == 1
        vdi_user = VdiUser.first

        vdi_user.vdi_desktop_pools << VdiDesktopPool.create

        task = MiqTask.create
        VdiUser.delete_users([VdiUser.first.id], task.id)
        VdiUser.count.should  == 1

        results = task.task_results
        results[:assigned].should == 1
        results[:error_msgs].length.should == 1
      end

    end
  end

  context "With user and desktop" do
    before(:each) do
     @zone = FactoryGirl.create(:small_environment)
     @ems =  @zone.ext_management_systems.first

     @user    = FactoryGirl.create(:vdi_user)
     @desktop = FactoryGirl.create(:vdi_desktop)
     @desktop.vm_vdi = Vm.first

     @farm = FactoryGirl.create(:vdi_farm_vmware)
     @pool = FactoryGirl.create(:vdi_desktop_pool, :name => 'RDP Test', :vendor => 'vmware', :enabled => true, :ext_management_systems => [@ems])

     @farm.vdi_desktop_pools << @pool
     @pool.vdi_desktops << @desktop
     @pool.ext_management_systems << @ems
    end

    it "user#desktop_assignment_add" do
      @user.desktop_assignment_add(@desktop)

      EmsEvent.count.should == 1
      event = EmsEvent.first
      event.event_type.should          == 'vm_vdi_user_assigned'
      event.vdi_user_id.should         == @user.id
      event.vdi_desktop_id.should      == @desktop.id
      event.vdi_desktop_pool_id.should == @pool.id
      event.vm_or_template_id.should   == @desktop.vm_vdi.id
    end

    it "user#desktop_assignment_add with attached desktop" do
      @user.desktop_assignment_add(@desktop)
      EmsEvent.destroy_all

      @user.should_receive(:create_assignment_event).never
      @user.desktop_assignment_add(@desktop)
      EmsEvent.count.should == 0
    end

    it "user#desktop_assignment_delete" do
      @user.should_receive(:create_assignment_event).never
      @user.vdi_desktops.delete(@desktop)
      EmsEvent.count.should == 0
    end

    it "user#desktop_assignment_delete with attached desktop" do
      @user.desktop_assignment_add(@desktop)
      EmsEvent.destroy_all
      @user.desktop_assignment_delete(@desktop)

      EmsEvent.count.should == 1
      EmsEvent.first.event_type.should == 'vm_vdi_user_unassigned'
    end

    it "desktop#desktop_assignment_add" do
      @user.desktop_assignment_add(@desktop)
      EmsEvent.count.should == 1
      event = EmsEvent.first
      event.event_type.should          == 'vm_vdi_user_assigned'
      event.vdi_user_id.should         == @user.id
      event.vdi_desktop_id.should      == @desktop.id
      event.vdi_desktop_pool_id.should == @pool.id
      event.vm_or_template_id.should   == @desktop.vm_vdi.id
    end

    it "desktop#desktop_assignment_add with attached desktop" do
      @user.desktop_assignment_add(@desktop)
      EmsEvent.destroy_all

      @user.should_receive(:create_assignment_event).never
      @user.desktop_assignment_add(@desktop)
      EmsEvent.count.should == 0
    end

    it "desktop#desktop_assignment_delete" do
      @user.should_receive(:create_assignment_event).never
      @user.desktop_assignment_delete(@desktop)
      EmsEvent.count.should == 0
    end

    it "desktop#desktop_assignment_delete with attached desktop" do
      @user.desktop_assignment_add(@desktop)
      EmsEvent.destroy_all
      @user.desktop_assignment_delete(@desktop)
      EmsEvent.count.should == 1
      EmsEvent.first.event_type.should == 'vm_vdi_user_unassigned'
    end
  end

end
