
require "spec_helper"

module MiqAeServiceVmOpenstackSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceVmOpenstack do

    ["openstack", "amazon"].each  do |t|

      context "for #{t}" do

        define_method(:service_class_for) do |part|
          case t
          when "amazon"
            "MiqAeMethodService::MiqAeServiceManageIQ_Providers_#{t.camelize}_CloudManager_#{part.to_s.camelize}".constantize
          else
            "MiqAeMethodService::MiqAeService#{part.to_s.camelize}#{t.camelize}".constantize
          end
        end

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
          @vm                  = service_class_for(:vm).find(vm.id)
        end

        it "#flavor" do
          @vm.flavor.should be_kind_of(service_class_for :flavor)
        end

        it "#availability_zone" do
          @vm.availability_zone.should be_kind_of(service_class_for :availability_zone)
        end

        it "#cloud_network" do
          @vm.cloud_network.should be_kind_of(MiqAeMethodService::MiqAeServiceCloudNetwork)
        end

        it "#cloud_subnet" do
          @vm.cloud_subnet.should be_kind_of(MiqAeMethodService::MiqAeServiceCloudSubnet)
        end

        it "#floating_ip" do
          @vm.floating_ip.should be_kind_of(service_class_for :floating_ip)
        end

        it "#security_groups" do
          @vm.security_groups.first.should be_kind_of(service_class_for :security_group)
        end

        it "#key_pairs" do
          @vm.key_pairs.first.should be_kind_of(service_class_for :auth_key_pair)
        end

      end
    end
  end
end
