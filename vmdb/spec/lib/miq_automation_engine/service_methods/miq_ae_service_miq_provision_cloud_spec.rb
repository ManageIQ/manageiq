require 'spec_helper'

module MiqAeServiceMiqProvisionCloudSpec
  describe MiqAeMethodService::MiqAeServiceMiqProvision do

    %w(amazon openstack).each  do |t|
      context "for #{t}" do

        before do
          @provider      = FactoryGirl.create("ems_#{t}_with_authentication")
          @cloud_image   = FactoryGirl.create("template_#{t}", :ext_management_system => @provider)
          @options       = {:src_vm_id => [@cloud_image.id, @cloud_image.name],
                            :pass      => 1}
          @user          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
          @miq_provision = FactoryGirl.create("miq_provision_#{t}",
                                              :provision_type => 'template',
                                              :state          => 'pending',
                                              :status         => 'Ok',
                                              :options        => @options,
                                              :userid         => @user.userid)
        end

        let(:workflow_klass) { "MiqProvision#{t.camelize}Workflow".constantize }
        let(:ae_svc_prov) { MiqAeMethodService::MiqAeServiceMiqProvision.find(@miq_provision.id) }

        context "#request_type" do
          %w(template clone_to_vm clone_to_template).each do |request_type|
            it "should set #{request_type} for #{t}" do
              @miq_provision.update_attributes(:request_type => request_type)
              ae_svc_prov.provision_type.should eq(request_type)
            end
          end
        end

        context "#target_type" do
          it "clone_to_template" do
            @miq_provision.update_attributes(:provision_type => 'clone_to_template')
            ae_svc_prov.target_type.should eq('template')
          end

          %w(template clone_to_vm).each do |provision_type|
            it "#{provision_type}" do
              @miq_provision.update_attributes(:provision_type => provision_type)
              ae_svc_prov.target_type.should eq('vm')
            end
          end
        end

        context "#source_type" do
          it "works with a template" do
            @cloud_image.update_attributes(:template => true)
            ae_svc_prov.source_type.should eq('template')
          end

          it "works with a vm" do
            @cloud_image.update_attributes(:template => false)
            ae_svc_prov.source_type.should eq('vm')
          end
        end

        context "customization_templates" do
          it "workflow exposes allowed_customization_templates" do
            workflow_klass.instance_methods.should include(:allowed_customization_templates)
          end

          context "with a customization_template" do
            before do
              @ct = FactoryGirl.create(:customization_template, :name => "Test Templates", :script => "script_text")
              ct_struct = [MiqHashStruct.new(:id               => @ct.id,
                                             :name             => @ct.name,
                                             :evm_object_class => @ct.class.base_class.name.to_sym)]
              workflow_klass.any_instance.stub(:allowed_customization_templates).and_return(ct_struct)
            end

            it "#eligible_customization_templates" do
              result = ae_svc_prov.eligible_customization_templates

              result.should be_kind_of(Array)
              result.first.class.should eq(MiqAeMethodService::MiqAeServiceCustomizationTemplate)
            end

            it "#set_customization_template" do
              ae_svc_prov.eligible_customization_templates.each { |ct| ae_svc_prov.set_customization_template(ct) }

              @miq_provision.reload.options[:customization_template_id].should     eq([@ct.id, @ct.name])
              @miq_provision.reload.options[:customization_template_script].should eq(@ct.script)
            end
          end
        end

        context "availability_zone" do
          it "workflow exposes allowed_availability_zones" do
            workflow_klass.instance_methods.should include(:allowed_availability_zones)
          end

          context "with an availability_zone" do
            before do
              @ci = FactoryGirl.create("availability_zone_#{t}")
              workflow_klass.any_instance.stub(:allowed_availability_zones).and_return(@ci.id => @ci.name)
            end

            it "#eligible_availability_zones" do
              result = ae_svc_prov.eligible_availability_zones

              result.should be_kind_of(Array)
              result.first.class.should eq("MiqAeMethodService::MiqAeServiceAvailabilityZone#{t.camelize}".constantize)
            end

            it "#set_availability_zone" do
              ae_svc_prov.eligible_availability_zones.each { |rsc| ae_svc_prov.set_availability_zone(rsc) }

              @miq_provision.reload.options[:placement_availability_zone].should eq([@ci.id, @ci.name])
            end
          end
        end

        context "instance_types" do
          it "workflow exposes allowed_instance_types" do
            workflow_klass.instance_methods.should include(:allowed_instance_types)
          end

          context "with an instance_type" do
            before do
              @ci = FactoryGirl.create("flavor_#{t}")
              workflow_klass.any_instance.stub(:allowed_instance_types).and_return(@ci.id => @ci.name)
            end

            it "#eligible_instance_types" do
              result = ae_svc_prov.eligible_instance_types

              result.should be_kind_of(Array)
              result.first.class.should eq("MiqAeMethodService::MiqAeServiceFlavor#{t.camelize}".constantize)
            end

            it "#set_instance_type" do
              ae_svc_prov.eligible_instance_types.each { |rsc| ae_svc_prov.set_instance_type(rsc) }

              @miq_provision.reload.options[:instance_type].should eq([@ci.id, @ci.name])
            end
          end
        end

        context "security_groups" do
          it "workflow exposes allowed_security_groups" do
            workflow_klass.instance_methods.should include(:allowed_security_groups)
          end

          context "with a security_group" do
            before do
              @ci = FactoryGirl.create("security_group_#{t}")
              workflow_klass.any_instance.stub(:allowed_security_groups).and_return(@ci.id => @ci.name)
            end

            it "#eligible_security_groups" do
              result = ae_svc_prov.eligible_security_groups

              result.should be_kind_of(Array)
              result.first.class.should eq("MiqAeMethodService::MiqAeServiceSecurityGroup#{t.camelize}".constantize)
            end

            it "#set_security_group" do
              ae_svc_prov.eligible_security_groups.each { |rsc| ae_svc_prov.set_security_group(rsc) }

              @miq_provision.reload.options[:security_groups].should eq([@ci.id])
            end
          end
        end

        context "cloud_networks" do
          it "workflow exposes allowed_cloud_networks" do
            workflow_klass.instance_methods.should include(:allowed_cloud_networks)
          end

          context "with a cloud_network" do
            before do
              @ci = FactoryGirl.create(:cloud_network)
              workflow_klass.any_instance.stub(:allowed_cloud_networks).and_return(@ci.id => @ci.name)
            end

            it "#eligible_cloud_networks" do
              result = ae_svc_prov.eligible_cloud_networks

              result.should be_kind_of(Array)
              result.first.class.should eq(MiqAeMethodService::MiqAeServiceCloudNetwork)
            end

            it "#set_cloud_network" do
              ae_svc_prov.eligible_cloud_networks.each { |rsc| ae_svc_prov.set_cloud_network(rsc) }

              @miq_provision.reload.options[:cloud_network].should eq([@ci.id, @ci.name])
            end
          end
        end

        context "cloud_subnets" do
          it "workflow exposes allowed_cloud_subnets" do
            workflow_klass.instance_methods.should include(:allowed_cloud_subnets)
          end

          context "with a cloud_subnet" do
            before do
              @ci = FactoryGirl.create(:cloud_subnet)
              workflow_klass.any_instance.stub(:allowed_cloud_subnets).and_return(@ci.id => @ci.name)
            end

            it "#eligible_cloud_subnets" do
              result = ae_svc_prov.eligible_cloud_subnets

              result.should be_kind_of(Array)
              result.first.class.should eq(MiqAeMethodService::MiqAeServiceCloudSubnet)
            end

            it "#set_cloud_subnet" do
              ae_svc_prov.eligible_cloud_subnets.each { |rsc| ae_svc_prov.set_cloud_subnet(rsc) }

              @miq_provision.reload.options[:cloud_subnet].should eq([@ci.id, @ci.name])
            end
          end
        end

        context "floating_ip_addresses" do
          it "workflow exposes allowed_floating_ip_addresses" do
            workflow_klass.instance_methods.should include(:allowed_floating_ip_addresses)
          end

          context "with a floating_ip_address" do
            before do
              @ci = FactoryGirl.create("floating_ip_#{t}")
              workflow_klass.any_instance.stub(:allowed_floating_ip_addresses).and_return(@ci.id => @ci.address)
            end

            it "#eligible_floating_ip_addresses" do
              result = ae_svc_prov.eligible_floating_ip_addresses

              result.should be_kind_of(Array)
              result.first.class.should eq("MiqAeMethodService::MiqAeServiceFloatingIp#{t.camelize}".constantize)
            end

            it "#set_floating_ip_address" do
              ae_svc_prov.eligible_floating_ip_addresses.each { |rsc| ae_svc_prov.set_floating_ip_address(rsc) }

              @miq_provision.reload.options[:floating_ip_address].should eq([@ci.id, @ci.address])
            end
          end
        end

        context "guest_access_key_pairs" do
          it "workflow exposes allowed_guest_access_key_pairs" do
            workflow_klass.instance_methods.should include(:allowed_guest_access_key_pairs)
          end

          context "with a key_pairs" do
            before do
              @ci = FactoryGirl.create("auth_key_pair_#{t}")
              workflow_klass.any_instance.stub(:allowed_guest_access_key_pairs).and_return(@ci.id => @ci.name)
            end

            it "#eligible_guest_access_key_pairs" do
              result = ae_svc_prov.eligible_guest_access_key_pairs

              result.should be_kind_of(Array)
              result.first.class.should eq("MiqAeMethodService::MiqAeServiceAuthKeyPair#{t.camelize}".constantize)
            end

            it "#set_guest_access_key_pairs" do
              ae_svc_prov.eligible_guest_access_key_pairs.each { |rsc| ae_svc_prov.set_guest_access_key_pair(rsc) }

              @miq_provision.reload.options[:guest_access_key_pair].should eq([@ci.id, @ci.name])
            end
          end
        end
      end
    end
  end
end
