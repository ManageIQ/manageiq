describe "AMAZON best fit" do

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ws) do
    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Cloud/VM/Provisioning&class=Placement" \
                            "&instance=default&message=amazon&" \
                            "MiqProvision::miq_provision=#{miq_provision.id}", user)
  end

  let(:ems) do
    FactoryGirl.create(:ems_amazon_with_authentication)
  end

  let(:vm_template) do
    FactoryGirl.create(:template_amazon,
                       :name                  => "template1",
                       :ext_management_system => ems)
  end
  let(:miq_provision) do
    FactoryGirl.create(:miq_provision_amazon,
                       :options => {:src_vm_id => vm_template.id},
                       :userid  => user.userid,
                       :state   => 'active',
                       :status  => 'Ok')
  end

  let(:t2_small_flavor) do
    FactoryGirl.create(:flavor_amazon, :ems_id                => ems.id,
                                       :name                  => 't2.small',
                                       :cloud_subnet_required => true)
  end

  let(:m2_small_flavor) do
    FactoryGirl.create(:flavor_amazon, :ems_id                => ems.id,
                                       :name                  => 'm2.small',
                                       :cloud_subnet_required => false)
  end

  let(:cloud_network1) do
    FactoryGirl.create(:cloud_network_amazon, :ems_id => ems.network_manager.id, :enabled => true)
  end

  let(:cloud_subnet1) do
    FactoryGirl.create(:cloud_subnet_amazon, :ems_id => ems.network_manager.id, :cloud_network_id => cloud_network1.id)
  end

  context "provision task object" do
    it "auto placement of t2 instances" do
      attrs = {:placement_auto => [true, 1],
               :instance_type  => [t2_small_flavor.id, "t2.small: T2 Small"]}
      cloud_subnet1
      miq_provision.update_attribute(:options, miq_provision.options.merge(attrs))
      ws.root

      miq_provision.reload

      expect(miq_provision.options[:cloud_network].first).to eql(cloud_network1.id)
      expect(miq_provision.options[:cloud_subnet].first).to eql(cloud_subnet1.id)
    end

    it "auto placement of m2 instances" do
      attrs = {:placement_auto => [true, 1],
               :instance_type  => [m2_small_flavor.id, "m2.small: M2 Small"]}
      cloud_subnet1
      miq_provision.update_attribute(:options, miq_provision.options.merge(attrs))
      ws.root

      check_attributes_not_set
    end

    it "manual placement" do
      attrs = {:placement_auto => [false, 0]}
      cloud_subnet1
      miq_provision.update_attribute(:options, miq_provision.options.merge(attrs))
      ws.root

      check_attributes_not_set
    end

    def check_attributes_not_set
      miq_provision.reload
      keys = miq_provision.options.keys
      expect(keys.include?(:cloud_network)).to be_falsey
      expect(keys.include?(:cloud_subnet)).to be_falsey
    end
  end
end
