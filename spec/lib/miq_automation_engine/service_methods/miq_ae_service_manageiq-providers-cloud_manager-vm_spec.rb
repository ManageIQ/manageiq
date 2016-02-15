
module MiqAeServiceVmOpenstackSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Vm do
    ["openstack", "amazon", "google"].each do |t|
      context "for #{t}" do
        define_method(:service_class_for) do |part|
          "MiqAeMethodService::MiqAeServiceManageIQ_Providers_#{t.camelize}_CloudManager_#{part.to_s.camelize}".constantize
        end

        before(:each) do
          vm                   =  FactoryGirl.create("vm_#{t}".to_sym)
          vm.availability_zone =  FactoryGirl.create("availability_zone_#{t}".to_sym)
          vm.flavor            =  FactoryGirl.create("flavor_#{t}".to_sym)
          if t != "google"
            vm.key_pairs << FactoryGirl.create("auth_key_pair_#{t}".to_sym)
            vm.floating_ip = FactoryGirl.create("floating_ip_#{t}".to_sym)
            vm.security_groups << FactoryGirl.create("security_group_#{t}".to_sym)
          end
          case t
          when "openstack"
            network = FactoryGirl.create(:cloud_network)
            subnet  = FactoryGirl.create(:cloud_subnet, :cloud_network => network)
            vm.network_ports << FactoryGirl.create(:network_port,
                                                   :device        => vm,
                                                   :cloud_network => network,
                                                   :cloud_subnet  => subnet)
          when "google"
            vm.cloud_network = FactoryGirl.create(:cloud_network)
          else
            # TODO(lsmola) when ready, all providers should act as openstack
            vm.cloud_network = FactoryGirl.create(:cloud_network)
            vm.cloud_subnet  = FactoryGirl.create(:cloud_subnet)
          end

          vm.save!
          @vm                  = service_class_for(:vm).find(vm.id)
        end

        it "#flavor" do
          expect(@vm.flavor).to be_kind_of(service_class_for :flavor)
        end

        it "#availability_zone" do
          expect(@vm.availability_zone).to be_kind_of(service_class_for :availability_zone)
        end

        it "#cloud_network" do
          expect(@vm.cloud_network).to be_kind_of(MiqAeMethodService::MiqAeServiceCloudNetwork)
        end

        if t != "google"
          it "#cloud_subnet" do
            expect(@vm.cloud_subnet).to be_kind_of(MiqAeMethodService::MiqAeServiceCloudSubnet)
          end

          it "#floating_ip" do
            expect(@vm.floating_ip).to be_kind_of(service_class_for :floating_ip)
          end

          it "#security_groups" do
            expect(@vm.security_groups.first).to be_kind_of(service_class_for :security_group)
          end

          it "#key_pairs" do
            expect(@vm.key_pairs.first).to be_kind_of(service_class_for :auth_key_pair)
          end
        end
      end
    end
  end
end
