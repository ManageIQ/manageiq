describe User do
  context "id set as Administrator" do
    before(:each) do
      # create User Role record...
      miq_user_role = FactoryGirl.create(
        :miq_user_role,
        :name      => "EvmRole-super_administrator",
        :read_only => true,
        :settings  => nil
      )

      # create Miq Group record...
      @miq_group = FactoryGirl.create(
        :miq_group,
        :description   => "EvmGroup-super_administrator",
        :group_type    => "system",
        :miq_user_role => miq_user_role
      )

      @miq_server = EvmSpecHelper.local_miq_server

      # create User record...
      @user = FactoryGirl.create(
        :user_admin,
        :email      => "admin@email.com",
        :password   => "smartvm",
        :settings   => {"Setting1"  => 1, "Setting2"  => 2, "Setting3"  => 3},
        :filters    => {"Filter1"   => 1, "Filter2"   => 2, "Filter3"   => 3},
        :miq_groups => [@miq_group],
        :first_name => "Bob",
        :last_name  => "Smith"
      )

      @self_service_role = FactoryGirl.create(
        :miq_user_role,
        :name     => "ss_role",
        :settings => {:restrictions => {:vms => :user_or_group}}
      )

      @self_service_group = FactoryGirl.create(
        :miq_group,
        :description   => "EvmGroup-self_service",
        :miq_user_role => @self_service_role
      )

      @limited_self_service_role = FactoryGirl.create(
        :miq_user_role,
        :name     => "lss_role",
        :settings => {:restrictions => {:vms => :user}}
      )

      @limited_self_service_group = FactoryGirl.create(
        :miq_group,
        :description   => "EvmGroup-limited_self_service",
        :miq_user_role => @limited_self_service_role
      )

      @miq_admin_role = FactoryGirl.create(
        :miq_user_role,
        :name      => "EvmRole-administrator",
        :read_only => true,
        :settings  => nil
      )

      @admin_group = FactoryGirl.create(
        :miq_group,
        :description   => "EvmGroup-administrator",
        :miq_user_role => @miq_admin_role
      )
    end

    it "should ensure presence of name" do
      expect(FactoryGirl.build(:user, :name => nil)).not_to be_valid
    end

    it "should ensure presence of user id" do
      expect(FactoryGirl.build(:user, :userid => nil)).not_to be_valid
    end

    it "should invalidate incorrect email address" do
      expect(FactoryGirl.build(:user, :email => "thisguy@@manageiq.com")).not_to be_valid
    end

    it "should validate email address with a value of nil" do
      expect(FactoryGirl.build(:user, :email => nil)).to be_valid
    end

    it "should save proper email address" do
      expect(FactoryGirl.build(:user, :email => "that.guy@manageiq.com")).to be_valid
    end
    it "should reject invalid characters in email address" do
      expect(FactoryGirl.build(:user, :email => "{{that.guy}}@manageiq.com")).not_to be_valid
    end

    it "should change user password" do
      password    = @user.password
      newpassword = "newpassword"
      @user.change_password(password, newpassword)
      expect(@user.password).to eq(newpassword)
    end

    it "should raise an error when asked to change user password" do
      password    = "wrongpwd"
      newpassword = "newpassword"

      expect { @user.change_password(password, newpassword) }
        .to raise_error(MiqException::MiqEVMLoginError)
    end

    it "should check for and get Managed and Belongs-to filters" do
      mfilters = {"managed"   => "m"}
      bfilters = {"belongsto" => "b"}
      @miq_group.set_managed_filters(mfilters)
      @miq_group.set_belongsto_filters(bfilters)
      @miq_group.save

      @user.reload

      expect(@user.has_filters?).to be_truthy
      expect(@user.get_managed_filters).to eq(mfilters)
      expect(@user.get_belongsto_filters).to eq(bfilters)
    end

    it "should check Self Service Roles" do
      @user.current_group = @self_service_group
      expect(@user.self_service?).to be_truthy

      @user.current_group = @limited_self_service_group
      expect(@user.self_service?).to be_truthy

      @miq_group.miq_user_role = nil
      @user.current_group = @miq_group
      expect(@user.self_service?).to be_falsey

      @user.current_group = nil
      expect(@user.self_service?).to be_falsey
    end

    it "should check Limited Self Service Roles" do
      @user.current_group = @limited_self_service_group
      expect(@user.limited_self_service?).to be_truthy

      @user.current_group = nil
      @user.current_group = @miq_group
      expect(@user.limited_self_service?).to be_falsey
    end

    it "should check Super Admin Roles" do
      expect(@user.super_admin_user?).to be_truthy

      @user.current_group = @admin_group
      expect(@user.super_admin_user?).to be_falsey

      @user.current_group = @limited_self_service_group
      expect(@user.super_admin_user?).to be_falsey
    end

    it "should check Admin Roles" do
      expect(@user.admin_user?).to be_truthy

      @user.current_group = @admin_group
      expect(@user.admin_user?).to be_truthy

      @user.current_group = @limited_self_service_group
      expect(@user.admin_user?).to be_falsey
    end

    it "should get Server time zone setting" do
      expect(@user.get_timezone).to eq("UTC")
    end

    it "with_my_timezone sets the user's zone in a block" do
      @user.settings.store_path(:display, :timezone, "Hawaii")
      @user.with_my_timezone do
        expect(Time.zone.to_s).to eq("(GMT-10:00) Hawaii")
      end
      expect(Time.zone.to_s).to eq("(GMT+00:00) UTC")
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
        @auth_config =
          {:authentication =>
            {:ldapport => "389",
              :basedn => "dc=manageiq,dc=com",
              :follow_referrals => false,
              :get_direct_groups => true,
              :bind_dn => "evm_demo@manageiq.com",
              :mode => "ldap", :user_proxies => [{}],
              :user_type => "userprincipalname",
              :bind_pwd => "blah",
              :ldap_role => true,
              :user_suffix => "manageiq.com",
              :group_memberships_max_depth => 2,
              :ldaphost => ["192.168.254.15"]
            }
          }
        stub_server_configuration(@auth_config)
        @miq_ldap = double('miq_ldap')
        allow(@miq_ldap).to receive_messages(:bind => false)
      end

      it "will fail task if user object not found in ldap" do
        allow(@miq_ldap).to receive_messages(:get_user_object => nil)

        expect(AuditEvent).to receive(:failure).once
        authenticate = Authenticator::Ldap.new(@auth_config[:authentication])
        allow(authenticate).to receive_messages(:ldap => @miq_ldap)

        expect(authenticate.authorize(@task.id, @fq_user)).to be_nil

        @task.reload
        expect(@task.state).to eq("Finished")
        expect(@task.status).to eq("Error")
        expect(@task.message).to match(/unable to find user object/)
      end

      it "will fail task if user group doesn't match an EVM role" do
        allow(@miq_ldap).to receive_messages(:get_user_object => "user object")
        allow(@miq_ldap).to receive_messages(:get_attr => nil)
        allow(@miq_ldap).to receive_messages(:normalize => "a-username")

        authenticate = Authenticator::Ldap.new(@auth_config[:authentication])
        allow(authenticate).to receive_messages(:ldap => @miq_ldap)
        allow(authenticate).to receive_messages(:groups_for => [])

        expect(AuditEvent).to receive(:failure).once
        expect(authenticate.authorize(@task.id, @fq_user)).to be_nil

        @task.reload
        expect(@task.state).to eq("Finished")
        expect(@task.status).to eq("Error")
        expect(@task.message).to match(/unable to match user's group membership/)
      end
    end

    context "#miq_groups=" do
      before(:each) do
        @filter1        = "this is filter 1"
        @group3.filters = @filter1
        @user = FactoryGirl.create(:user, :miq_groups => [@group3])
      end

      it "sets miq_groups" do
        expect(@user.miq_groups).to match_array [@group3]
      end

      it "sets current_group" do
        expect(@user.current_group).to eq(@group3)
      end

      it "sets filters" do
        expect(@user.filters).to eq(@group3.filters)
        expect(@user.filters).to eq(@filter1)
      end

      it "when including current group" do
        @user.miq_groups = [@group1, @group2, @group3]
        expect(@user.valid?).to be_truthy
        expect(@user.current_group).to eq(@group3)
      end

      it "when not including currrent group" do
        @user.miq_groups = [@group1, @group2]
        expect(@user.valid?).to be_truthy
        expect(@user.current_group).to eq(@group1)
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
        expect(@user.current_group).to eq(@group1)
      end

      it "sets filters" do
        expect(@user.filters).to eq(@group1.filters)
        expect(@user.filters).to eq(@filter1)
      end

      it "when belongs to miq_groups" do
        expect(@user.valid?).to be_truthy
      end

      it "when not belongs to miq_groups" do
        @user.miq_groups = [@group2, @group3]
        expect(@user.current_group).to eq(@group2)
      end

      it "when nil" do
        @user.current_group = nil
        expect(@user.valid?).to be_truthy
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

      @hw1 = FactoryGirl.create(:hardware, :cpu_total_cores => @num_cpu, :memory_mb => @ram_size)
      @hw2 = FactoryGirl.create(:hardware, :cpu_total_cores => @num_cpu, :memory_mb => @ram_size)
      @hw3 = FactoryGirl.create(:hardware, :cpu_total_cores => @num_cpu, :memory_mb => @ram_size)
      @hw4 = FactoryGirl.create(:hardware, :cpu_total_cores => @num_cpu, :memory_mb => @ram_size)
      @disk1 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw1.id)
      @disk2 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw2.id)
      @disk3 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw3.id)
      @disk4 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw4.id)

      @active_vm = FactoryGirl.create(:vm_vmware,
                                      :name         => "Active VM",
                                      :evm_owner_id => @user.id,
                                      :ems_id       => @ems.id,
                                      :storage_id   => @storage.id,
                                      :hardware     => @hw1)
      @archived_vm = FactoryGirl.create(:vm_vmware,
                                        :name         => "Archived VM",
                                        :evm_owner_id => @user.id,
                                        :hardware     => @hw2)
      @orphaned_vm = FactoryGirl.create(:vm_vmware,
                                        :name         => "Orphaned VM",
                                        :evm_owner_id => @user.id,
                                        :storage_id   => @storage.id,
                                        :hardware     => @hw3)
      @retired_vm = FactoryGirl.create(:vm_vmware,
                                       :name         => "Retired VM",
                                       :evm_owner_id => @user.id,
                                       :retired      => true,
                                       :hardware     => @hw4)
    end

    it "#active_vms" do
      expect(@user.active_vms).to match_array([@active_vm])
    end

    it "#allocated_memory" do
      expect(@user.allocated_memory).to eq(@ram_size.megabyte)
    end

    it "#allocated_vcpu" do
      expect(@user.allocated_vcpu).to eq(@num_cpu)
    end

    it "#allocated_storage" do
      expect(@user.allocated_storage).to eq(@disk_size)
    end

    it "#provisioned_storage" do
      expect(@user.provisioned_storage).to eq(@ram_size.megabyte + @disk_size)
    end

    %w(allocated_memory allocated_vcpu allocated_storage provisioned_storage).each do |vcol|
      it "should have virtual column #{vcol} " do
        expect(described_class).to have_virtual_column "#{vcol}", :integer
      end
    end
  end

  it 'should invalidate email address that contains "\n"' do
    group = FactoryGirl.create(:miq_group)
    user = FactoryGirl.create(:user,
                              :email      => "admin@email.com",
                              :miq_groups => [group]
                             )
    expect(user).to be_valid

    user.email = "admin@email.com
                  ); INSERT INTO users
                  (password, userid) VALUES ('bar', 'foo')--"
    expect(user).not_to be_valid
  end

  context ".authenticate_with_http_basic" do
    let(:user) { FactoryGirl.create(:user, :password => "dummy") }

    it "should login with good username/password" do
      expect(User.authenticate_with_http_basic(user.userid, user.password)).to eq([true, user.userid])
    end

    it "should fail with bad username" do
      bad_userid = "bad_userid"
      expect(User.authenticate_with_http_basic(bad_userid, user.password)).to eq([false, bad_userid])
    end

    it "should fail with bad password" do
      expect(User.authenticate_with_http_basic(user.userid, "bad_pwd")).to eq([false, user.userid])
    end
  end

  context ".seed" do
    include_examples(".seed called multiple times", 2)

    include_examples("seeding users with", [])

    include_examples("seeding users with", [MiqUserRole, MiqGroup])
  end

  context "#accessible_vms" do
    before do
      @user = FactoryGirl.create(:user_admin)

      @self_service_role = FactoryGirl.create(
        :miq_user_role,
        :name     => "ss_role",
        :settings => {:restrictions => {:vms => :user_or_group}}
      )
      @self_service_group = FactoryGirl.create(:miq_group, :miq_user_role => @self_service_role)

      @limited_self_service_role = FactoryGirl.create(
        :miq_user_role,
        :name     => "lss_role",
        :settings => {:restrictions => {:vms => :user}}
      )
      @limited_self_service_group = FactoryGirl.create(:miq_group, :miq_user_role => @limited_self_service_role)

      @vm = []
      (1..5).each { |i| @vm[i] = FactoryGirl.create(:vm_redhat, :name => "vm_#{i}") }
    end
    subject(:accessible_vms) { @user.accessible_vms }

    it "non self service user" do
      expect(accessible_vms.size).to eq(5)
    end

    it "self service user" do
      @user.update_attributes(:miq_groups => [@self_service_group])
      @vm[1].update_attributes(:evm_owner => @user)
      @vm[2].update_attributes(:miq_group => @self_service_group)

      expect(accessible_vms.size).to eq(2)
    end

    it "limited self service user" do
      @user.update_attributes(:miq_groups => [@limited_self_service_group])
      @vm[1].update_attributes(:evm_owner => @user)
      @vm[2].update_attributes(:miq_group => @self_service_group)
      @vm[3].update_attributes(:miq_group => @limited_self_service_group)

      expect(accessible_vms.size).to eq(1)
    end
  end

  describe ".all_users_of_group" do
    it "finds users" do
      g  = FactoryGirl.create(:miq_group)
      g2 = FactoryGirl.create(:miq_group)

      FactoryGirl.create(:user)
      u_one  = FactoryGirl.create(:user, :miq_groups => [g])
      u_two  = FactoryGirl.create(:user, :miq_groups => [g, g2], :current_group => g)

      expect(described_class.all_users_of_group(g)).to match_array([u_one, u_two])
      expect(described_class.all_users_of_group(g2)).to match_array([u_two])
    end
  end

  describe "#current_group_by_description=" do
    subject { FactoryGirl.create(:user, :miq_groups => [g1, g2], :current_group => g1) }
    let(:g1) { FactoryGirl.create(:miq_group) }
    let(:g2) { FactoryGirl.create(:miq_group) }

    it "ignores blank" do
      subject.current_group_by_description = ""
      expect(subject.current_group).to eq(g1)
      expect(subject.miq_group_description).to eq(g1.description)
    end

    it "ignores not found" do
      subject.current_group_by_description = "not_found"
      expect(subject.current_group).to eq(g1)
      expect(subject.miq_group_description).to eq(g1.description)
    end

    it "ignores a group that you do not belong" do
      subject.current_group_by_description = FactoryGirl.create(:miq_group).description
      expect(subject.current_group).to eq(g1)
      expect(subject.miq_group_description).to eq(g1.description)
    end

    it "sets by description" do
      subject.current_group_by_description = g2.description
      expect(subject.current_group).to eq(g2)
      expect(subject.miq_group_description).to eq(g2.description)
    end

    context "as a super admin" do
      subject { FactoryGirl.create(:user, :role => "super_administrator") }

      it "sets any group, regardless of group membership" do
        expect(subject).to be_super_admin_user

        subject.current_group_by_description = g2.description
        expect(subject.current_group).to eq(g2)
      end
    end
  end

  describe ".find_by_lower_email" do
    it "uses cache" do
      u = FactoryGirl.build(:user_with_email)
      expect(User.find_by_lower_email(u.email.upcase, u)).to eq(u)
    end

    it "finds in the table" do
      u = FactoryGirl.create(:user_with_email)
      expect(User.find_by_lower_email(u.email.upcase)).to eq(u)
    end
  end

  describe "#current_tenant" do
    let(:user1) { FactoryGirl.create(:user_with_group) }

    it "sets the tenant" do
      User.with_user(user1) do
        expect(User.current_tenant).to be_truthy
        expect(User.current_tenant).to eq(user1.current_tenant)
      end
    end
  end

  describe "#current_user=" do
    let(:user1) { FactoryGirl.create(:user) }

    it "sets the user" do
      User.current_user = user1
      expect(User.current_userid).to eq(user1.userid)
      expect(User.current_user).to eq(user1)
    end
  end

  describe "#with_user" do
    let(:user1) { FactoryGirl.create(:user) }
    let(:user2) { FactoryGirl.create(:user) }

    it "sets the user" do
      User.with_user(user1) do
        expect(User.current_userid).to eq(user1.userid)
        expect(User.current_user).to eq(user1)
        User.with_user(user2) do
          expect(User.current_userid).to eq(user2.userid)
          expect(User.current_user).to eq(user2)
        end
        expect(User.current_userid).to eq(user1.userid)
        expect(User.current_user).to eq(user1)
      end
    end

    # sorry. please help me delete this use case / parameter
    it "supports a userid with a nil user" do
      User.with_user(user1) do
        User.with_user(nil, "oleg") do
          expect(User.current_userid).to eq("oleg")
          expect(User.current_user).not_to be
        end
        expect(User.current_userid).to eq(user1.userid)
        expect(User.current_user).to eq(user1)
      end
    end
  end

  context ".super_admin" do
    it "has super_admin" do
      FactoryGirl.create(:miq_group, :role => "super_administrator")
      User.seed
      expect(User.super_admin).to be_super_admin_user
    end
  end
end
