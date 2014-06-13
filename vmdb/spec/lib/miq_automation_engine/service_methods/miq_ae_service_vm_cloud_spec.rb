
require "spec_helper"

module MiqAeServiceVmOpenstackSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceVmOpenstack do

    ["openstack", "amazon"].each  do |t|

      context "for #{t}" do

        before(:each) do
          vm                   =  FactoryGirl.create("vm_#{t}".to_sym)
          vm.availability_zone =  FactoryGirl.create("availability_zone_#{t}".to_sym)
          vm.flavor            =  FactoryGirl.create("flavor_#{t}".to_sym)
          vm.key_pairs         << FactoryGirl.create("auth_key_pair_#{t}".to_sym)
          vm.cloud_network     =  FactoryGirl.create(:cloud_network)
          vm.cloud_subnet      =  FactoryGirl.create(:cloud_subnet)
          vm.floating_ip       =  FactoryGirl.create("floating_ip_#{t}".to_sym)
          vm.security_groups   << FactoryGirl.create("security_group_#{t}".to_sym)
          vm.save!
          @vm                  = "MiqAeMethodService::MiqAeServiceVm#{t.camelize}".constantize.find(vm.id)
        end

        it "#flavor" do
          @vm.flavor.should be_kind_of("MiqAeMethodService::MiqAeServiceFlavor#{t.camelize}".constantize)
        end

        it "#availability_zone" do
          @vm.availability_zone.should be_kind_of("MiqAeMethodService::MiqAeServiceAvailabilityZone#{t.camelize}".constantize)
        end

        it "#cloud_network" do
          @vm.cloud_network.should be_kind_of(MiqAeMethodService::MiqAeServiceCloudNetwork)
        end

        it "#cloud_subnet" do
          @vm.cloud_subnet.should be_kind_of(MiqAeMethodService::MiqAeServiceCloudSubnet)
        end

        it "#floating_ip" do
          @vm.floating_ip.should be_kind_of("MiqAeMethodService::MiqAeServiceFloatingIp#{t.camelize}".constantize)
        end

        it "#security_groups" do
          @vm.security_groups.first.should be_kind_of("MiqAeMethodService::MiqAeServiceSecurityGroup#{t.camelize}".constantize)
        end

        it "#key_pairs" do
          @vm.key_pairs.first.should be_kind_of("MiqAeMethodService::MiqAeServiceAuthKeyPair#{t.camelize}".constantize)
        end

      end
    end
  end
end
