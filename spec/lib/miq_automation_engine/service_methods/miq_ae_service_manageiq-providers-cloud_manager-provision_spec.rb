module MiqAeServiceManageIQ_Providers_CloudManager_ProvisionSpec
  describe MiqAeMethodService::MiqAeServiceMiqProvision do
    %w(amazon openstack google azure).each do |t|
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

        let(:workflow_klass) { MiqProvisionWorkflow.class_for_platform(t) }
        let(:ae_svc_prov) { MiqAeMethodService::MiqAeServiceMiqProvision.find(@miq_provision.id) }

        context "#request_type" do
          %w(template clone_to_vm clone_to_template).each do |request_type|
            it "should set #{request_type} for #{t}" do
              @miq_provision.update_attributes(:request_type => request_type)
              expect(ae_svc_prov.provision_type).to eq(request_type)
            end
          end
        end

        context "#target_type" do
          it "clone_to_template" do
            @miq_provision.update_attributes(:provision_type => 'clone_to_template')
            expect(ae_svc_prov.target_type).to eq('template')
          end

          %w(template clone_to_vm).each do |provision_type|
            it provision_type.to_s do
              @miq_provision.update_attributes(:provision_type => provision_type)
              expect(ae_svc_prov.target_type).to eq('vm')
            end
          end
        end

        context "#source_type" do
          it "works with a template" do
            @cloud_image.update_attributes(:template => true)
            expect(ae_svc_prov.source_type).to eq('template')
          end

          it "works with a vm" do
            @cloud_image.update_attributes(:template => false)
            expect(ae_svc_prov.source_type).to eq('vm')
          end
        end

        context "customization_templates" do
          it "workflow exposes allowed_customization_templates" do
            expect(workflow_klass.instance_methods).to include(:allowed_customization_templates)
          end

          context "with a customization_template" do
            before do
              @ct = FactoryGirl.create(:customization_template, :name => "Test Templates", :script => "script_text")
              ct_struct = [MiqHashStruct.new(:id               => @ct.id,
                                             :name             => @ct.name,
                                             :evm_object_class => @ct.class.base_class.name.to_sym)]
              allow_any_instance_of(workflow_klass).to receive(:allowed_customization_templates).and_return(ct_struct)
            end

            it "#eligible_customization_templates" do
              result = ae_svc_prov.eligible_customization_templates

              expect(result).to be_kind_of(Array)
              expect(result.first.class).to eq(MiqAeMethodService::MiqAeServiceCustomizationTemplate)
            end

            it "#set_customization_template" do
              ae_svc_prov.eligible_customization_templates.each { |ct| ae_svc_prov.set_customization_template(ct) }

              expect(@miq_provision.reload.options[:customization_template_id]).to     eq([@ct.id, @ct.name])
              expect(@miq_provision.reload.options[:customization_template_script]).to eq(@ct.script)
            end
          end
        end

        if t != "azure"
          context "availability_zone" do
            it "workflow exposes allowed_availability_zones" do
              expect(workflow_klass.instance_methods).to include(:allowed_availability_zones)
            end

            context "with an availability_zone" do
              before do
                @ci = FactoryGirl.create("availability_zone_#{t}")
                allow_any_instance_of(workflow_klass).to receive(:allowed_availability_zones).and_return(@ci.id => @ci.name)
              end

              it "#eligible_availability_zones" do
                result = ae_svc_prov.eligible_availability_zones

                expect(result).to be_kind_of(Array)
                expect(result.first.class).to eq("MiqAeMethodService::MiqAeService#{@ci.class.name.gsub(/::/, '_')}".constantize)
              end

              it "#set_availability_zone" do
                ae_svc_prov.eligible_availability_zones.each { |rsc| ae_svc_prov.set_availability_zone(rsc) }

                expect(@miq_provision.reload.options[:placement_availability_zone]).to eq([@ci.id, @ci.name])
              end
            end
          end
        end

        context "instance_types" do
          it "workflow exposes allowed_instance_types" do
            expect(workflow_klass.instance_methods).to include(:allowed_instance_types)
          end

          context "with an instance_type" do
            before do
              @ci = FactoryGirl.create("flavor_#{t}")
              allow_any_instance_of(workflow_klass).to receive(:allowed_instance_types).and_return(@ci.id => @ci.name)
            end

            it "#eligible_instance_types" do
              result = ae_svc_prov.eligible_instance_types

              expect(result).to be_kind_of(Array)
              expect(result.first.class).to eq("MiqAeMethodService::MiqAeService#{@ci.class.name.gsub(/::/, '_')}".constantize)
            end

            it "#set_instance_type" do
              ae_svc_prov.eligible_instance_types.each { |rsc| ae_svc_prov.set_instance_type(rsc) }

              expect(@miq_provision.reload.options[:instance_type]).to eq([@ci.id, @ci.name])
            end
          end
        end

        if t != "google"
          context "security_groups" do
            before do
              @ci = FactoryGirl.create("security_group_#{t}")
              @c2 = FactoryGirl.create("security_group_#{t}")
              allow_any_instance_of(workflow_klass).to receive(:allowed_security_groups).and_return(@ci.id => @ci.name, @c2.id => @c2.name)
            end

            it "workflow exposes allowed_security_groups" do
              expect(workflow_klass.instance_methods).to include(:allowed_security_groups)
            end

            it "#eligible_security_groups" do
              result = ae_svc_prov.eligible_security_groups

              expect(result).to be_kind_of(Array)
              expect(result.first.class).to eq("MiqAeMethodService::MiqAeService#{@ci.class.name.gsub(/::/, '_')}".constantize)
            end

            it "#set_security_group" do
              rsc = ae_svc_prov.eligible_security_groups.first
              ae_svc_prov.set_security_group(rsc)

              expect(@miq_provision.reload.options[:security_groups]).to eq([@ci.id])
            end

            it "#set_security_groups" do
              rscs = ae_svc_prov.eligible_security_groups
              ae_svc_prov.set_security_groups(rscs)

              expect(@miq_provision.reload.options[:security_groups]).to match_array([@ci.id, @c2.id])
            end
          end
        end

        context "cloud_networks" do
          it "workflow exposes allowed_cloud_networks" do
            expect(workflow_klass.instance_methods).to include(:allowed_cloud_networks)
          end

          context "with a cloud_network" do
            before do
              @ci = FactoryGirl.create(:cloud_network)
              allow_any_instance_of(workflow_klass).to receive(:allowed_cloud_networks).and_return(@ci.id => @ci.name)
            end

            it "#eligible_cloud_networks" do
              result = ae_svc_prov.eligible_cloud_networks

              expect(result).to be_kind_of(Array)
              expect(result.first.class).to eq(MiqAeMethodService::MiqAeServiceCloudNetwork)
            end

            it "#set_cloud_network" do
              ae_svc_prov.eligible_cloud_networks.each { |rsc| ae_svc_prov.set_cloud_network(rsc) }

              expect(@miq_provision.reload.options[:cloud_network]).to eq([@ci.id, @ci.name])
            end
          end
        end

        if t != "google"
          context "cloud_subnets" do
            it "workflow exposes allowed_cloud_subnets" do
              expect(workflow_klass.instance_methods).to include(:allowed_cloud_subnets)
            end

            context "with a cloud_subnet" do
              before do
                @ci = FactoryGirl.create(:cloud_subnet)
                allow_any_instance_of(workflow_klass).to receive(:allowed_cloud_subnets).and_return(@ci.id => @ci.name)
              end

              it "#eligible_cloud_subnets" do
                result = ae_svc_prov.eligible_cloud_subnets

                expect(result).to be_kind_of(Array)
                expect(result.first.class).to eq(MiqAeMethodService::MiqAeServiceCloudSubnet)
              end

              it "#set_cloud_subnet" do
                ae_svc_prov.eligible_cloud_subnets.each { |rsc| ae_svc_prov.set_cloud_subnet(rsc) }

                expect(@miq_provision.reload.options[:cloud_subnet]).to eq([@ci.id, @ci.name])
              end
            end
          end
        end

        if t != "google" && t != "azure"
          context "floating_ip_addresses" do
            it "workflow exposes allowed_floating_ip_addresses" do
              expect(workflow_klass.instance_methods).to include(:allowed_floating_ip_addresses)
            end

            context "with a floating_ip_address" do
              before do
                @ci = FactoryGirl.create("floating_ip_#{t}")
                allow_any_instance_of(workflow_klass).to receive(:allowed_floating_ip_addresses).and_return(@ci.id => @ci.address)
              end

              it "#eligible_floating_ip_addresses" do
                result = ae_svc_prov.eligible_floating_ip_addresses

                expect(result).to be_kind_of(Array)
                expect(result.first.class).to eq("MiqAeMethodService::MiqAeService#{@ci.class.name.gsub(/::/, '_')}".constantize)
              end

              it "#set_floating_ip_address" do
                ae_svc_prov.eligible_floating_ip_addresses.each { |rsc| ae_svc_prov.set_floating_ip_address(rsc) }

                expect(@miq_provision.reload.options[:floating_ip_address]).to eq([@ci.id, @ci.address])
              end
            end
          end
        end

        if t != "google" && t != "azure"
          context "guest_access_key_pairs" do
            it "workflow exposes allowed_guest_access_key_pairs" do
              expect(workflow_klass.instance_methods).to include(:allowed_guest_access_key_pairs)
            end

            context "with a key_pairs" do
              before do
                @ci = FactoryGirl.create("auth_key_pair_#{t}")
                allow_any_instance_of(workflow_klass).to receive(:allowed_guest_access_key_pairs).and_return(@ci.id => @ci.name)
              end

              it "#eligible_guest_access_key_pairs" do
                result = ae_svc_prov.eligible_guest_access_key_pairs

                expect(result).to be_kind_of(Array)
                expect(result.first.class).to eq("MiqAeMethodService::MiqAeService#{@ci.class.name.gsub(/::/, '_')}".constantize)
              end

              it "#set_guest_access_key_pairs" do
                ae_svc_prov.eligible_guest_access_key_pairs.each { |rsc| ae_svc_prov.set_guest_access_key_pair(rsc) }

                expect(@miq_provision.reload.options[:guest_access_key_pair]).to eq([@ci.id, @ci.name])
              end
            end
          end
        end

        if t == 'azure'
          context "resource_groups" do
            it "workflow exposes allowed_resource_groups" do
              expect(workflow_klass.instance_methods).to include(:allowed_resource_groups)
            end

            context "with a resource_group" do
              before do
                @rg = FactoryGirl.create("resource_group")
                allow_any_instance_of(workflow_klass).to receive(:allowed_resource_groups).and_return(@rg.id => @rg.name)
              end

              it "#eligible_resource_groups" do
                result = ae_svc_prov.eligible_resource_groups

                expect(result).to be_kind_of(Array)
                expect(result.first.class).to eq("MiqAeMethodService::MiqAeServiceResourceGroup".constantize)
              end

              it "#set_resource_group" do
                ae_svc_prov.eligible_resource_groups.each { |rg| ae_svc_prov.set_resource_group(rg) }

                expect(@miq_provision.reload.options[:resource_group]).to eq([@rg.id, @rg.name])
              end
            end
          end
        end

        if t == 'openstack'
          context "cloud_tenants" do
            it "workflow exposes allowed_cloud_tenants" do
              expect(workflow_klass.instance_methods).to include(:allowed_cloud_tenants)
            end

            context "with a cloud_tenant" do
              before do
                @ct = FactoryGirl.create("cloud_tenant")
                allow_any_instance_of(workflow_klass).to receive(:allowed_cloud_tenants).and_return(@ct.id => @ct.name)
              end

              it "#eligible_cloud_tenants" do
                result = ae_svc_prov.eligible_cloud_tenants

                expect(result).to be_kind_of(Array)
                expect(result.first.class).to eq("MiqAeMethodService::MiqAeServiceCloudTenant".constantize)
              end

              it "#set_cloud_tenant" do
                ae_svc_prov.eligible_cloud_tenants.each { |rsc| ae_svc_prov.set_cloud_tenant(rsc) }

                expect(@miq_provision.reload.options[:cloud_tenant]).to eq([@ct.id, @ct.name])
              end
            end
          end
        end
      end
    end
  end
end
