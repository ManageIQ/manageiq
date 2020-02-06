RSpec.describe AssignedServerRole do
  context "and Server Role seeded for 1 Region/Zone" do
    before do
      @miq_server = EvmSpecHelper.local_miq_server
    end

    context "Server Role" do
      before do
        @server_role = FactoryBot.create(
          :server_role,
          :name              => "smartproxy",
          :description       => "SmartProxy",
          :max_concurrent    => 1,
          :external_failover => false,
          :role_scope        => "zone"
        )

        @priority = AssignedServerRole::DEFAULT_PRIORITY
        @assigned_server_role = FactoryBot.create(
          :assigned_server_role,
          :miq_server_id  => @miq_server.id,
          :server_role_id => @server_role.id,
          :active         => true,
          :priority       => @priority
        )
      end

      it "should return Server Role name" do
        expect(@assigned_server_role.name).to eq("smartproxy")
      end

      it "should toggle Active indicator" do
        @assigned_server_role.deactivate
        expect(@assigned_server_role.active).to be_falsey
        @assigned_server_role.activate
        expect(@assigned_server_role.active).to be_truthy
      end

      it "should reset priority" do
        @assigned_server_role.reset
        expect(@assigned_server_role.active).to be_falsey
        expect(@assigned_server_role.priority).to eq(2)
      end

      it "should check if -master- role is supported" do
        expect(@assigned_server_role.master_supported?).to be_truthy
      end

      it "should check if Miq Server is set as -master-" do
        expect(@assigned_server_role.is_master?).to be_falsey

        @assigned_server_role.priority = 1
        expect(@assigned_server_role.is_master?).to be_falsey
      end

      it "should set Miq Server as -master-" do
        @assigned_server_role.set_master
        expect(@assigned_server_role.priority).to eq(1)
      end

      it "should remove Miq Server as -master-" do
        @assigned_server_role.remove_master
        expect(@assigned_server_role.priority).to eq(2)
      end

      it "should activate Assigned Server Role" do
        @assigned_server_role.active = false
        expect(@assigned_server_role.activate).to be_truthy
      end

      it "should deactivate Assigned Server Role" do
        @assigned_server_role.active = true
        expect(@assigned_server_role.activate).to be_falsey
      end
    end
  end

  context "and Server Roles seeded for 1 Region and 2 Zones" do
    before do
      @miq_region = FactoryBot.create(:miq_region, :region => 1)
      allow(MiqRegion).to receive(:my_region).and_return(@miq_region)

      @miq_zone1 = FactoryBot.create(:zone, :name => "Zone 1", :description => "Test Zone One")
      @miq_server_11 = FactoryBot.create(:miq_server, :zone => @miq_zone1)
      @miq_server_12 = FactoryBot.create(:miq_server, :zone => @miq_zone1)

      @miq_zone2 = FactoryBot.create(:zone, :name => "Zone 2", :description => "Test Zone Two")
      @miq_server_21 = FactoryBot.create(:miq_server, :zone => @miq_zone2)
      @miq_server_22 = FactoryBot.create(:miq_server, :zone => @miq_zone2)

      @server_role_zu = FactoryBot.create(
        :server_role,
        :name              => "zu",
        :description       => "Zone Unlimited",
        :max_concurrent    => 0,
        :external_failover => false,
        :role_scope        => "zone"
      )

      @server_role_zl = FactoryBot.create(
        :server_role,
        :name              => "zl",
        :description       => "Zone Limited",
        :max_concurrent    => 1,
        :external_failover => false,
        :role_scope        => "zone"
      )

      @server_role_ru = FactoryBot.create(
        :server_role,
        :name              => "ru",
        :description       => "Region Unlimited",
        :max_concurrent    => 0,
        :external_failover => false,
        :role_scope        => "region"
      )

      @server_role_rl = FactoryBot.create(
        :server_role,
        :name              => "rl",
        :description       => "Region Limited",
        :max_concurrent    => 1,
        :external_failover => false,
        :role_scope        => "region"
      )

      @priority = AssignedServerRole::DEFAULT_PRIORITY

      @assigned_server_role_11_zu = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_11.id,
        :server_role_id => @server_role_zu.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_11_zl = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_11.id,
        :server_role_id => @server_role_zl.id,
        :active         => true,
        :priority       => AssignedServerRole::HIGH_PRIORITY
      )

      @assigned_server_role_11_ru = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_11.id,
        :server_role_id => @server_role_ru.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_11_rl = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_11.id,
        :server_role_id => @server_role_rl.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_12_zu = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_12.id,
        :server_role_id => @server_role_zu.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_12_zl = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_12.id,
        :server_role_id => @server_role_zl.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_12_ru = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_12.id,
        :server_role_id => @server_role_ru.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_12_rl = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_12.id,
        :server_role_id => @server_role_rl.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_21_zu = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_21.id,
        :server_role_id => @server_role_zu.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_21_zl = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_21.id,
        :server_role_id => @server_role_zl.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_21_ru = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_21.id,
        :server_role_id => @server_role_ru.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_21_rl = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_21.id,
        :server_role_id => @server_role_rl.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_22_zu = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_22.id,
        :server_role_id => @server_role_zu.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_22_zl = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_22.id,
        :server_role_id => @server_role_zl.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_22_ru = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_22.id,
        :server_role_id => @server_role_ru.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )

      @assigned_server_role_22_rl = FactoryBot.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server_22.id,
        :server_role_id => @server_role_rl.id,
        :active         => true,
        :priority       => AssignedServerRole::DEFAULT_PRIORITY
      )
    end

    it "should set priority for Server Role scope" do
      @assigned_server_role_11_zu.set_priority(AssignedServerRole::HIGH_PRIORITY)
      expect(@assigned_server_role_11_zu.priority).to eq(AssignedServerRole::HIGH_PRIORITY)

      @assigned_server_role_11_zl.set_priority(AssignedServerRole::HIGH_PRIORITY)
      expect(@assigned_server_role_11_zl.priority).to eq(AssignedServerRole::HIGH_PRIORITY)
    end

    it "should activate Server Role for a Region" do
      @assigned_server_role_11_rl.active = false
      @assigned_server_role_11_rl.activate_in_region
      expect(@assigned_server_role_11_rl.active).to be_truthy
    end

    it "should deactivate Server Role for a Region" do
      @assigned_server_role_11_rl.active = true
      @assigned_server_role_11_rl.deactivate_in_region
      expect(@assigned_server_role_11_rl.active).to be_falsey
    end

    it "should activate Server Role for a Zone" do
      @assigned_server_role_11_zl.active = false
      @assigned_server_role_11_zl.activate_in_zone
      expect(@assigned_server_role_11_zl.active).to be_truthy
    end

    it "should deactivate Server Role for a Zone" do
      @assigned_server_role_11_zl.active = true
      @assigned_server_role_11_zl.deactivate_in_zone
      expect(@assigned_server_role_11_zl.active).to be_falsey
    end
  end
end
