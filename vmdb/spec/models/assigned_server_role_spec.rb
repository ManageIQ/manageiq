require "spec_helper"

describe AssignedServerRole do

  context "and Server Role seeded for 1 Region/Zone" do

    before(:each) do
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)

      MiqRegion.seed

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
    end

    context "Server Role" do

      before (:each) do
        @server_role = FactoryGirl.create(
                      :server_role,
                      :name               => "smartproxy",
                      :description        => "SmartProxy",
                      :max_concurrent     => 1,
                      :external_failover  => false,
                      :role_scope         => "zone"
                      )

        @priority = AssignedServerRole::DEFAULT_PRIORITY
        @assigned_server_role = FactoryGirl.create(
                              :assigned_server_role,
                              :miq_server_id    => @miq_server.id,
                              :server_role_id   => @server_role.id,
                              :active           => true,
                              :priority         => @priority
                              )
      end

      it "should return Server Role name" do
        @assigned_server_role.name.should == "smartproxy"
      end

      it "should toggle Active indicator" do
        @assigned_server_role.deactivate
        @assigned_server_role.active.should be_false
        @assigned_server_role.activate
        @assigned_server_role.active.should be_true
      end

      it "should reset priority" do
        @assigned_server_role.reset
        @assigned_server_role.active.should be_false
        @assigned_server_role.priority.should == 2
      end

      it "should check if -master- role is supported" do
        @assigned_server_role.master_supported?.should be_true
      end

      it "should check if Miq Server is set as -master-" do
        @assigned_server_role.is_master?.should be_false

        @assigned_server_role.priority = 1
        @assigned_server_role.is_master?.should be_false
      end

      it "should set Miq Server as -master-" do
        @assigned_server_role.set_master
        @assigned_server_role.priority.should == 1
      end

      it "should remove Miq Server as -master-" do
        @assigned_server_role.remove_master
        @assigned_server_role.priority.should == 2
      end

      it "should activate Assigned Server Role" do
        @assigned_server_role.active = false
        @assigned_server_role.activate.should be_true
      end

      it "should deactivate Assigned Server Role" do
        @assigned_server_role.active = true
        @assigned_server_role.activate.should be_false
      end

    end

  end


  context "and Server Roles seeded for 1 Region and 2 Zones" do

    before(:each) do
      @miq_region = FactoryGirl.create(:miq_region, :region => 1)
      MiqRegion.stub(:my_region).and_return(@miq_region)

      @miq_zone1 = FactoryGirl.create(:zone, :name => "Zone 1", :description => "Test Zone One")

      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)
      @miq_server_11 = FactoryGirl.create(
                    :miq_server,
                    :guid         => @guid,
                    :status       => "started",
                    :name         => "Server 1",
                    :os_priority  => nil,
                    :is_master    => false,
                    :zone_id      => @miq_zone1.id
                    )

      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)
      @miq_server_12 = FactoryGirl.create(
                    :miq_server,
                    :guid         => @guid,
                    :status       => "started",
                    :name         => "Server 2",
                    :os_priority  => nil,
                    :is_master    => false,
                    :zone_id      => @miq_zone1.id
                    )

      @miq_zone2 = FactoryGirl.create(:zone, :name => "Zone 2", :description => "Test Zone Two")

      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)
      @miq_server_21 = FactoryGirl.create(
                    :miq_server,
                    :guid         => @guid,
                    :status       => "started",
                    :name         => "Server 3",
                    :os_priority  => nil,
                    :is_master    => false,
                    :zone_id      => @miq_zone2.id
                    )

      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)
      @miq_server_22 = FactoryGirl.create(
                    :miq_server,
                    :guid         => @guid,
                    :status       => "started",
                    :name         => "Server 4",
                    :os_priority  => nil,
                    :is_master    => false,
                    :zone_id      => @miq_zone2.id
                    )

      @server_role_zu = FactoryGirl.create(
                      :server_role,
                      :name               => "zu",
                      :description        => "Zone Unlimited",
                      :max_concurrent     => 0,
                      :external_failover  => false,
                      :role_scope         => "zone"
                      )

      @server_role_zl = FactoryGirl.create(
                      :server_role,
                      :name               => "zl",
                      :description        => "Zone Limited",
                      :max_concurrent     => 1,
                      :external_failover  => false,
                      :role_scope         => "zone"
                      )

      @server_role_ru = FactoryGirl.create(
                      :server_role,
                      :name               => "ru",
                      :description        => "Region Unlimited",
                      :max_concurrent     => 0,
                      :external_failover  => false,
                      :role_scope         => "region"
                      )

      @server_role_rl = FactoryGirl.create(
                      :server_role,
                      :name               => "rl",
                      :description        => "Region Limited",
                      :max_concurrent     => 1,
                      :external_failover  => false,
                      :role_scope         => "region"
                      )

      @priority = AssignedServerRole::DEFAULT_PRIORITY

      @assigned_server_role_11_zu = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_11.id,
                                  :server_role_id   => @server_role_zu.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_11_zl = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_11.id,
                                  :server_role_id   => @server_role_zl.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::HIGH_PRIORITY
                                  )

      @assigned_server_role_11_ru = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_11.id,
                                  :server_role_id   => @server_role_ru.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_11_rl = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_11.id,
                                  :server_role_id   => @server_role_rl.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_12_zu = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_12.id,
                                  :server_role_id   => @server_role_zu.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_12_zl = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_12.id,
                                  :server_role_id   => @server_role_zl.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_12_ru = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_12.id,
                                  :server_role_id   => @server_role_ru.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_12_rl = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_12.id,
                                  :server_role_id   => @server_role_rl.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_21_zu = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_21.id,
                                  :server_role_id   => @server_role_zu.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_21_zl = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_21.id,
                                  :server_role_id   => @server_role_zl.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_21_ru = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_21.id,
                                  :server_role_id   => @server_role_ru.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_21_rl = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_21.id,
                                  :server_role_id   => @server_role_rl.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_22_zu = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_22.id,
                                  :server_role_id   => @server_role_zu.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_22_zl = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_22.id,
                                  :server_role_id   => @server_role_zl.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_22_ru = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_22.id,
                                  :server_role_id   => @server_role_ru.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

      @assigned_server_role_22_rl = FactoryGirl.create(
                                  :assigned_server_role,
                                  :miq_server_id    => @miq_server_22.id,
                                  :server_role_id   => @server_role_rl.id,
                                  :active           => true,
                                  :priority         => AssignedServerRole::DEFAULT_PRIORITY
                                  )

    end

    it "should set priority for Server Role scope" do

      @assigned_server_role_11_zu.set_priority(AssignedServerRole::HIGH_PRIORITY)
      @assigned_server_role_11_zu.priority.should == AssignedServerRole::HIGH_PRIORITY

      @assigned_server_role_11_zl.set_priority(AssignedServerRole::HIGH_PRIORITY)
      @assigned_server_role_11_zl.priority.should == AssignedServerRole::HIGH_PRIORITY
    end

      it "should activate Server Role for a Region" do
        @assigned_server_role_11_rl.active = false
        @assigned_server_role_11_rl.activate_in_region
        @assigned_server_role_11_rl.active.should be_true
      end

      it "should deactivate Server Role for a Region" do
        @assigned_server_role_11_rl.active = true
        @assigned_server_role_11_rl.deactivate_in_region
        @assigned_server_role_11_rl.active.should be_false
      end

      it "should activate Server Role for a Zone" do
        @assigned_server_role_11_zl.active = false
        @assigned_server_role_11_zl.activate_in_zone
        @assigned_server_role_11_zl.active.should be_true
      end

      it "should deactivate Server Role for a Zone" do
        @assigned_server_role_11_zl.active = true
        @assigned_server_role_11_zl.deactivate_in_zone
        @assigned_server_role_11_zl.active.should be_false
      end

  end

end
