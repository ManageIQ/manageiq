
module MiqAeServiceVmOpenstackSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Vm do
    ["openstack", "amazon", "google"].each do |t|
      context "for #{t}" do
        define_method(:service_class_for) do |part|
          case part.to_s.camelize
          when "FloatingIp", "SecurityGroup", "CloudSubnet", "CloudNetwork"
            return "MiqAeMethodService::MiqAeServiceManageIQ_Providers_#{t.camelize}_NetworkManager_#{part.to_s.camelize}".constantize
          end
          "MiqAeMethodService::MiqAeServiceManageIQ_Providers_#{t.camelize}_CloudManager_#{part.to_s.camelize}".constantize
        end

        before(:each) do
          vm                   =  FactoryGirl.create("vm_#{t}".to_sym)
          vm.availability_zone =  FactoryGirl.create("availability_zone_#{t}".to_sym)
          vm.flavor            =  FactoryGirl.create("flavor_#{t}".to_sym)
          if t != "google"
            vm.key_pairs << FactoryGirl.create("auth_key_pair_#{t}".to_sym)
          end

          network = FactoryGirl.create("cloud_network_#{t}".to_sym)
          subnet  = FactoryGirl.create("cloud_subnet_#{t}".to_sym, :cloud_network => network)
          vm.network_ports << network_port = FactoryGirl.create("network_port_#{t}".to_sym,
                                                                :device       => vm)
          FactoryGirl.create(:cloud_subnet_network_port, :cloud_subnet => subnet, :network_port => network_port)

          network_port.security_groups << FactoryGirl.create("security_group_#{t}".to_sym)
          network_port.floating_ip = FactoryGirl.create("floating_ip_#{t}".to_sym, :vm => vm)

          vm.save!
          @vm                  = service_class_for(:vm).find(vm.id)
        end

        it "#flavor" do
          expect(@vm.flavor).to be_kind_of(service_class_for(:flavor))
        end

        it "#availability_zone" do
          expect(@vm.availability_zone).to be_kind_of(service_class_for(:availability_zone))
        end

        it "#cloud_network" do
          expect(@vm.cloud_network).to be_kind_of(service_class_for(:cloud_network))
        end

        it "#cloud_subnet" do
          expect(@vm.cloud_subnet).to be_kind_of(service_class_for(:cloud_subnet))
        end

        it "#floating_ip" do
          expect(@vm.floating_ip).to be_kind_of(service_class_for(:floating_ip))
        end

        it "#security_groups" do
          expect(@vm.security_groups.first).to be_kind_of(service_class_for(:security_group))
        end

        it "#key_pairs" do
          expect(@vm.key_pairs.first).to be_kind_of(service_class_for(:auth_key_pair)) if t != "google"
        end
      end
    end
  end
end
