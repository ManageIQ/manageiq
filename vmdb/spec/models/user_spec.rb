require "spec_helper"

describe User do

  context "id set as Administrator" do

    before(:each) do
      MiqRegion.seed

      # create User Role record...
      @miq_user_role = FactoryGirl.create(
                      :miq_user_role,
                      :name       => "EvmRole-super_administrator",
                      :read_only  => true,
                      :settings   => nil
                      )

      # create Miq Group record...
      @guid = MiqUUID.new_guid
      MiqGroup.stub(:my_guid).and_return(@guid)
      @miq_group = FactoryGirl.create(
                  :miq_group,
                  :guid             => @guid,
                  :description      => "EvmGroup-super_administrator",
                  :group_type       => "system",
                  :miq_user_role    => @miq_user_role
                  )

      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)

      @zone         = FactoryGirl.create(:zone)
      @miq_server   = FactoryGirl.create(
                    :miq_server,
                    :guid         => @guid,
                    :status       => "started",
                    :name         => "EVM",
                    :os_priority  => nil,
                    :is_master    => false,
                    :zone         => @zone
                    )
      MiqServer.my_server(true)

      # create User record...
      @user = FactoryGirl.create(
            :user_admin,
            :email          => "admin@email.com",
            :password       => "smartvm",
            :settings       => {"Setting1"  => 1, "Setting2"  => 2, "Setting3"  => 3 },
            :filters        => {"Filter1"   => 1, "Filter2"   => 2, "Filter3"   => 3 },
            :miq_groups     => [@miq_group],
            :first_name     => "Bob",
            :last_name      => "Smith"
            )

      @self_service_role = FactoryGirl.create(
        :miq_user_role,
        :name               => "ss_role",
        :settings           => {:restrictions => {:vms => :user_or_group}}
      )

      @self_service_group = FactoryGirl.create(
        :miq_group,
        :description        => "EvmGroup-self_service",
        :miq_user_role      => @self_service_role
      )

      @limited_self_service_role = FactoryGirl.create(
        :miq_user_role,
        :name               => "lss_role",
        :settings           => {:restrictions => {:vms => :user}}
      )

      @limited_self_service_group = FactoryGirl.create(
        :miq_group,
        :description        => "EvmGroup-limited_self_service",
        :miq_user_role      => @limited_self_service_role
      )

      @miq_admin_role = FactoryGirl.create(
                      :miq_user_role,
                      :name       => "EvmRole-administrator",
                      :read_only  => true,
                      :settings   => nil
                      )

      @admin_group = FactoryGirl.create(
        :miq_group,
        :description        => "EvmGroup-administrator",
        :miq_user_role      => @miq_admin_role
      )
    end

    it "should ensure presence of name" do
      @user.save.should be_true
      @user.name = nil
      @user.save.should be_false
    end

    it "should ensure presence of user id" do
      @user.save.should be_true
      @user.userid = nil
      @user.save.should be_false
    end

    # it "should ensure presence of region" do
    #   @user.region = nil
    #   @user.save.should be_false
    # end

    it "should invalidate incorrect email address" do
      @user.valid?.should be_true
      @user.email = "thisguy@@manageiq.com"
      @user.valid?.should be_false
    end

    it "should validate email address with a value of nil" do
      @user.email = nil
      @user.valid?.should be_true
    end

    it "should save proper email address" do
      @user.email = "that.guy@manageiq.com"
      @user.valid?.should be_true
    end
    it "should reject invalid characters in email address" do
      @user.email = "{{that.guy}}@manageiq.com"
      @user.valid?.should be_false
    end

    it "should change user password" do
      password    = @user.password
      newpassword = "newpassword"
      @user.change_password(password, newpassword)
      @user.password.should == newpassword
    end

    it "should raise an error when asked to change user password" do
      password    = "wrongpwd"
      newpassword = "newpassword"

      lambda {
              @user.change_password(password, newpassword)
             }.should
             raise_error( MiqException::MiqEVMLoginError,
                            "old password does not match current password"
                        )
    end

    it "should check for and get Managed and Belongs-to filters" do
      mfilters = { "managed"   => "m" }
      bfilters = { "belongsto" => "b" }
      @miq_group.set_managed_filters(mfilters)
      @miq_group.set_belongsto_filters(bfilters)
      @miq_group.save

      @user.reload

      @user.has_filters?.should be_true
      @user.get_managed_filters.should    == mfilters
      @user.get_belongsto_filters.should  == bfilters
    end

    it "should check Self Service Roles" do
      @user.current_group = @self_service_group
      @user.self_service_user?.should be_true

      @user.current_group = @limited_self_service_group
      @user.self_service_user?.should be_true

      @miq_group.miq_user_role = nil
      @user.current_group = @miq_group
      @user.self_service_user?.should be_false

      @user.current_group = nil
      @user.self_service_user?.should be_false
    end

    it "should check Limited Self Service Roles" do
      @user.current_group = @limited_self_service_group
      @user.limited_self_service_user?.should be_true

      @user.current_group = nil
      @user.current_group = @miq_group
      @user.limited_self_service_user?.should be_false
    end

    it "should check Super Admin Roles" do
      @user.super_admin_user?.should be_true

      @user.current_group = @admin_group
      @user.super_admin_user?.should be_false

      @user.current_group = @limited_self_service_group
      @user.super_admin_user?.should be_false
    end

    it "should check Admin Roles" do
      @user.admin_user?.should be_true

      @user.current_group = @admin_group
      @user.admin_user?.should be_true

      @user.current_group = @limited_self_service_group
      @user.admin_user?.should be_false
    end

    it "should get Server time zone setting" do
      @user.get_timezone.should == "UTC"
    end

    it "with_my_timezone sets the user's zone in a block" do
      @user.settings.store_path(:display, :timezone, "Hawaii")
      @user.with_my_timezone do
        Time.zone.to_s.should == "(GMT-10:00) Hawaii"
      end
      Time.zone.to_s.should == "(GMT+00:00) UTC"
    end
  end

  context "miq_groups" do
    before(:each) do
      @group1 = FactoryGirl.create(:miq_group, :description => "EvmGroup 1")
      @group2 = FactoryGirl.create(:miq_group, :description => "EvmGroup 2")
      @group3 = FactoryGirl.create(:miq_group, :description => "EvmGroup 3")
    end

    context "#authorize_ldap" do
      before(:each) do
        @fq_user = "thin1@manageiq.com"
        @task = MiqTask.create(:name => "LDAP User Authorization of '#{@fq_user}'", :userid => @fq_user)
        auth_config =
          {:authentication =>
            {:ldapport=>"389",
              :basedn=>"dc=manageiq,dc=com",
              :follow_referrals=>false,
              :get_direct_groups=>true,
              :bind_dn=>"evm_demo@manageiq.com",
              :mode=>"ldap", :user_proxies=>[{}],
              :user_type=>"userprincipalname",
              :bind_pwd=>"blah",
              :ldap_role=>true,
              :user_suffix=>"manageiq.com",
              :group_memberships_max_depth=>2,
              :ldaphost=>["192.168.254.15"]
            }
          }
        vmdb_config = double("vmdb_config")
        vmdb_config.stub(:config => auth_config)
        VMDB::Config.stub(:new).with("vmdb").and_return(vmdb_config)
        @miq_ldap = double('miq_ldap')
        @miq_ldap.stub(:bind => false)
      end

      it "will fail task if user object not found in ldap" do
        @miq_ldap.stub(:get_user_object => nil)
        MiqLdap.stub(:new).and_return(@miq_ldap)

        AuditEvent.should_receive(:failure).once
        User.authorize_ldap(@task.id, @fq_user).should be_nil

        @task.reload
        @task.state.should == "Finished"
        @task.status.should == "Error"
        @task.message.should =~ /unable to find user object/
      end

      it "will fail task if user group doesn't match an EVM role" do
        @miq_ldap.stub(:get_user_object => "user object")
        @miq_ldap.stub(:get_attr => nil)
        @miq_ldap.stub(:normalize => "a-username")
        MiqLdap.stub(:new).and_return(@miq_ldap)
        User.stub(:getUserMembership).and_return([])

        AuditEvent.should_receive(:failure).once
        User.authorize_ldap(@task.id, @fq_user).should be_nil

        @task.reload
        @task.state.should == "Finished"
        @task.status.should == "Error"
        @task.message.should =~ /unable to match user's group membership/
      end
    end

    context "#miq_groups=" do
      before(:each) do
        @filter1        = "this is filter 1"
        @group3.filters = @filter1
        @user = FactoryGirl.create(:user, :miq_groups => [@group3])
      end

      it "sets miq_groups" do
        @user.miq_groups.should have_same_elements [@group3]
      end

      it "sets current_group" do
        @user.current_group.should == @group3
      end

      it "sets filters" do
        @user.filters.should == @group3.filters
        @user.filters.should == @filter1
      end

      it "when including current group" do
        @user.miq_groups = [@group1, @group2, @group3]
        @user.valid?.should be_true
        @user.current_group.should == @group3
      end

      it "when not including currrent group" do
        @user.miq_groups = [@group1, @group2]
        @user.valid?.should be_true
        @user.current_group.should == @group1
      end

      it "when nil" do
        expect { @user.miq_groups = nil }.to raise_error(NoMethodError)
      end
    end

    context "#current_group=" do
      before(:each) do
        @filter1            = "this is filter 1"
        @group1.filters     = @filter1
        @user = FactoryGirl.create(:user, :miq_groups => [@group1, @group2])
      end

      it "sets current_group" do
        @user.current_group.should == @group1
      end

      it "sets filters" do
        @user.filters.should == @group1.filters
        @user.filters.should == @filter1
      end

      it "when belongs to miq_groups" do
        @user.valid?.should be_true
      end

      it "when not belongs to miq_groups" do
        @user.miq_groups = [@group2, @group3]
        @user.current_group.should == @group2
      end

      it "when nil" do
        @user.current_group = nil
        @user.valid?.should be_true
      end
    end
  end

  context "Testing active VM aggregation" do
    before :each do
      @ram_size = 1024
      @disk_size = 1_000_000
      @num_cpu = 2

      group = FactoryGirl.create(:miq_group)
      @user = FactoryGirl.create(:user, :miq_groups => [group])
      @ems = FactoryGirl.create(:ems_vmware, :name => "test_vcenter")
      @storage  = FactoryGirl.create(:storage, :name => "test_storage_nfs", :store_type => "NFS")

      @hw1 = FactoryGirl.create(:hardware, :numvcpus => @num_cpu, :memory_cpu => @ram_size)
      @hw2 = FactoryGirl.create(:hardware, :numvcpus => @num_cpu, :memory_cpu => @ram_size)
      @hw3 = FactoryGirl.create(:hardware, :numvcpus => @num_cpu, :memory_cpu => @ram_size)
      @hw4 = FactoryGirl.create(:hardware, :numvcpus => @num_cpu, :memory_cpu => @ram_size)
      @disk1 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw1.id)
      @disk2 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw2.id)
      @disk3 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw3.id)
      @disk4 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw4.id)

      @active_vm = FactoryGirl.create(:vm_vmware,
                                  :name => "Active VM",
                                  :evm_owner_id => @user.id,
                                  :ems_id => @ems.id,
                                  :storage_id => @storage.id,
                                  :hardware => @hw1)
      @archived_vm = FactoryGirl.create(:vm_vmware,
                                    :name => "Archived VM",
                                    :evm_owner_id => @user.id,
                                    :hardware => @hw2)
      @orphaned_vm = FactoryGirl.create(:vm_vmware,
                                    :name => "Orphaned VM",
                                    :evm_owner_id => @user.id,
                                    :storage_id => @storage.id,
                                    :hardware => @hw3)
      @retired_vm = FactoryGirl.create(:vm_vmware,
                                   :name => "Retired VM",
                                   :evm_owner_id => @user.id,
                                   :retired => true,
                                   :hardware => @hw4)
    end

    it "#active_vms" do
      @user.active_vms.should have_same_elements([@active_vm])
    end

    it "#allocated_memory" do
      @user.allocated_memory.should == @ram_size.megabyte
    end

    it "#allocated_vcpu" do
      @user.allocated_vcpu.should == @num_cpu
    end

    it "#allocated_storage" do
      @user.allocated_storage.should == @disk_size
    end

    it "#provisioned_storage" do
      @user.provisioned_storage.should == @ram_size.megabyte + @disk_size
    end

    %w(allocated_memory allocated_vcpu allocated_storage provisioned_storage).each do |vcol|
      it "should have virtual column #{vcol} " do
        described_class.should have_virtual_column "#{vcol}", :integer
      end
    end
  end

  it 'should invalidate email address that contains "\n"' do
    group = FactoryGirl.create(:miq_group)
    user = FactoryGirl.create(:user,
                              :email         => "admin@email.com",
                              :miq_groups    => [group]
    )
    user.should be_valid

    user.email = "admin@email.com
                  ); INSERT INTO users
                  (password, userid) VALUES ('bar', 'foo')--"
    user.should_not be_valid
  end

  context "#group_ids_of_subscribed_widget_sets" do
    subject { @user.group_ids_of_subscribed_widget_sets }
    before do
      @group = FactoryGirl.create(:miq_group, :description => 'dev group')
      @user  = FactoryGirl.create(:user, :name => 'cloud', :userid => 'cloud', :miq_groups => [@group])
      @ws_group = FactoryGirl.create(:miq_widget_set, :name => 'Home', :owner => @group)
      FactoryGirl.create(:miq_widget_set, :name => 'Home', :userid => @user.userid, :group_id => @group.id)
    end

    it "none group" do
      @group.users.destroy_all
      @group.destroy
      expect(subject).to be_empty
    end

    it "one group" do
      expect(subject).to eq([@group.id])
    end

    it "multiple groups" do
      group2 = FactoryGirl.create(:miq_group, :description => '2nd group')
      FactoryGirl.create(:miq_widget_set, :name => 'Home', :userid => @user.userid, :group_id => group2.id)
      expect(subject).to have_same_elements([@group.id, group2.id])
    end

    it "a belong to group is deleted" do
      group2 = FactoryGirl.create(:miq_group, :description => '2nd group')
      FactoryGirl.create(:miq_widget_set, :name => 'Home', :userid => @user.userid, :group_id => group2.id)

      @user.destroy_widget_sets_for_group(group2)
      expect(subject).to eq([@group.id])
    end
  end

  context ".authenticate_with_http_basic" do
    let(:user) { FactoryGirl.create(:user, :password => "dummy") }

    it "should login with good username/password" do
      User.authenticate_with_http_basic(user.userid, user.password).should eq([true, user.userid])
    end

    it "should fail with bad username" do
      bad_userid = "bad_userid"
      User.authenticate_with_http_basic(bad_userid, user.password).should eq([false, bad_userid])
    end

    it "should fail with bad password" do
      User.authenticate_with_http_basic(user.userid, "bad_pwd").should eq([false, user.userid])
    end
  end

  context ".seed" do
    before { MiqRegion.seed }

    it "empty database" do
      User.seed
      expect(User.where(:userid => "admin").first.current_group).to be_nil
    end

    it "with only MiqGroup seeded" do
      MiqGroup.seed
      User.seed
      expect(User.where(:userid => "admin").first.current_group).to be_nil
    end

    it "with role and MiqGroup seeded" do
      MiqUserRole.seed
      MiqGroup.seed
      User.seed

      admin = User.where(:userid => "admin").first
      expect(admin.current_group.name).to eq "EvmGroup-super_administrator"
      expect(admin.current_group.miq_user_role_name).to eq "EvmRole-super_administrator"
    end
  end
end
