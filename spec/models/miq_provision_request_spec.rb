RSpec.describe MiqProvisionRequest do
  context "#request_task_class_from" do
    it "retrieves the provision class when the vm has EMS" do
      ems = FactoryBot.create(:ems_vmware)
      vm = FactoryBot.create(:vm_vmware, :ext_management_system => ems)
      expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id})).to eq ManageIQ::Providers::Vmware::InfraManager::Provision
      expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id, :provision_type => "pxe"})).to eq ManageIQ::Providers::Vmware::InfraManager::ProvisionViaPxe

      ems = FactoryBot.create(:ems_redhat)
      vm = FactoryBot.create(:vm_redhat, :ext_management_system => ems)
      expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id})).to eq ManageIQ::Providers::Redhat::InfraManager::Provision

      ems = FactoryBot.create(:ems_openstack)
      vm = FactoryBot.create(:vm_openstack, :ext_management_system => ems)
      expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id})).to eq ManageIQ::Providers::Openstack::CloudManager::Provision

      ems = FactoryBot.create(:ems_amazon)
      vm = FactoryBot.create(:vm_amazon, :ext_management_system => ems)
      expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id})).to eq ManageIQ::Providers::Amazon::CloudManager::Provision
    end

    it "fails to retrieve the provision class when the vm has no EMS" do
      vm = FactoryBot.create(:vm_redhat)
      expect { described_class.request_task_class_from('options' => {:src_vm_id => vm.id}) }.to raise_error(MiqException::MiqProvisionError)
    end

    it "fails to retrieve the provision class when the vm does not exist" do
      expect { described_class.request_task_class_from('options' => {:src_vm_id => -1 }) }.to raise_error(MiqException::MiqProvisionError)
    end
  end

  context "A new provision request," do
    let(:approver)    { FactoryBot.create(:user_miq_request_approver) }
    let(:user)        { FactoryBot.create(:user) }
    let(:ems)         { FactoryBot.create(:ems_vmware) }
    let(:vm)          { FactoryBot.create(:vm_vmware, :name => "vm1", :location => "abc/def.vmx") }
    let(:vm_template) { FactoryBot.create(:template_vmware, :name => "template1", :ext_management_system => ems) }

    it "should not be created without requester being specified" do
      expect { FactoryBot.create(:miq_provision_request, :requester => nil) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should not be created with a valid userid but no vm being specified" do
      expect { FactoryBot.create(:miq_provision_request, :requester => user, :source => nil) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should be created from either a VM or Template" do
      expect { FactoryBot.create(:miq_provision_request, :requester => user, :src_vm_id => vm_template.id) }.not_to raise_error
      expect { FactoryBot.create(:miq_provision_request, :requester => user, :src_vm_id => vm.id) }.not_to raise_error
    end

    it "should not be created with a valid userid but invalid vm being specified" do
      expect { FactoryBot.create(:miq_provision_request, :requester => user, :src_vm_id => 42) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    context "with a valid userid and source vm," do
      before do
        @pr = FactoryBot.create(:miq_provision_request, :requester => user, :src_vm_id => vm_template.id, :options => {:owner_email => 'tester@miq.com'})
        @request = @pr.miq_request
      end

      it "should create an MiqProvisionRequest" do
        expect(MiqProvisionRequest.count).to eq(1)
        expect(MiqProvisionRequest.first).to eq(@pr)
        expect(@pr.valid?).to be_truthy
        expect(@pr.approved?).to be_falsey
      end

      it "should create a valid MiqRequest" do
        expect(@pr.miq_request).to eq(MiqRequest.first)
        expect(@pr.miq_request.valid?).to be_truthy
        expect(@pr.miq_request.approval_state).to eq("pending_approval")
        expect(@pr.miq_request.resource).to eq(@pr)
        expect(@pr.miq_request.requester_userid).to eq(user.userid)
        expect(@pr.miq_request.stamped_on).to be_nil

        expect(@pr.miq_request.approved?).to be_falsey
        expect(MiqApproval.count).to eq(1)
        expect(@pr.miq_request.first_approval).to eq(MiqApproval.first)
      end

      it "should return the correct queue_name" do
        expect(@pr.my_queue_name).to eq(vm_template.ext_management_system.queue_name_for_ems_operations)
      end

      it "should return a workflow class" do
        expect(@pr.workflow_class).to eq(ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow)
      end

      context "when calling call_automate_event_queue" do
        before do
          @event_name = "request_created"
          @pr.miq_request.call_automate_event_queue(@event_name)
        end

        it "should create proper MiqQueue item" do
          expect(MiqQueue.count).to eq(1)
          q = MiqQueue.first
          expect(q.class_name).to eq(@pr.miq_request.class.name)
          expect(q.instance_id).to eq(@pr.miq_request.id)
          expect(q.method_name).to eq("call_automate_event")
          expect(q.args).to eq([@event_name])
          expect(q.zone).to eq(ems.zone.name)
        end
      end

      context "after MiqRequest is deleted," do
        before { @request.destroy }

        it "should delete MiqProvisionRequest" do
          expect(MiqProvisionRequest.count).to eq(0)
        end

        it "should delete MiqApproval" do
          expect(MiqApproval.count).to eq(0)
        end

        it "should not delete Approver" do
          expect { approver.reload }.not_to raise_error
        end
      end

      context "when calling quota methods" do
        before { EvmSpecHelper.create_guid_miq_server_zone }

        it "should return a hash for quota methods" do
          [:vms_by_group, :vms_by_owner, :retired_vms_by_group, :retired_vms_by_owner, :provisions_by_group, :provisions_by_owner,
           :requests_by_group, :requests_by_owner, :active_provisions_by_group, :active_provisions_by_owner, :active_provisions].each do |quota_method|
            expect(@pr.check_quota(quota_method)).to be_kind_of(Hash)
          end
        end

        it "should return stats from quota methods" do
          prov_options = {:number_of_vms => [2, '2'], :owner_email => 'tester@miq.com', :vm_memory => [1024, '1024'], :number_of_cpus => [2, '2']}
          @pr2 = FactoryBot.create(:miq_provision_request, :requester => user, :src_vm_id => vm_template.id, :options => prov_options)

          stats = @pr.check_quota(:requests_by_owner)
          expect(stats).to be_kind_of(Hash)

          expect(stats[:class_name]).to eq("MiqProvisionRequest")
          expect(stats[:count]).to eq(2)
          expect(stats[:memory]).to eq(2.gigabytes)
          expect(stats[:cpu]).to eq(4)
          expect(stats.fetch_path(:active, :class_name)).to eq("MiqProvision")
        end

        context "for cloud and infra providers," do
          def create_request(user, vm_template, prov_options)
            FactoryBot.create(:miq_provision_request, :requester      => user,
                                                       :description    => "request",
                                                       :tenant         => user.current_tenant,
                                                       :source         => vm_template,
                                                       :status         => 'Ok',
                                                       :process        => true,
                                                       :request_state  => 'active',
                                                       :approval_state => 'approved',
                                                       :src_vm_id      => vm_template.id,
                                                       :options        => prov_options.merge(:owner_email => user.email, :requester_group => user.miq_groups.first.description))
          end

          let(:create_requests) do
            ems = FactoryBot.create(:ems_vmware)
            vmware_tenant = FactoryBot.create(:tenant)
            group = FactoryBot.create(:miq_group, :tenant => vmware_tenant)
            @vmware_user1 = FactoryBot.create(:user_with_email, :miq_groups => [group])
            @vmware_user2 = FactoryBot.create(:user_with_email, :miq_groups => [group])
            hardware = FactoryBot.create(:hardware, :cpu1x2, :memory_mb => 512)
            @vmware_template = FactoryBot.create(:template_vmware,
                                                  :ext_management_system => ems,
                                                  :hardware              => hardware)
            prov_options = {:number_of_vms => [2, '2'], :vm_memory => [1024, '1024'], :number_of_cpus => [2, '2']}
            2.times { create_request(@vmware_user1, @vmware_template, prov_options) }

            2.times { create_request(@vmware_user2, @vmware_template, prov_options) }

            ems = FactoryBot.create(:ems_google_with_authentication,
                                     :availability_zones => [FactoryBot.create(:availability_zone_google)])
            google_tenant = FactoryBot.create(:tenant)
            group = FactoryBot.create(:miq_group, :tenant => google_tenant)
            @google_user1 = FactoryBot.create(:user_with_email, :miq_groups => [group])
            @google_user2 = FactoryBot.create(:user_with_email, :miq_groups => [group])
            @google_template = FactoryBot.create(:template_google, :ext_management_system => ems)
            flavor = FactoryBot.create(:flavor_google, :ems_id => ems.id,
                                        :cpus => 4, :cpu_cores => 1, :memory => 1024)
            prov_options = {:number_of_vms => 1, :src_vm_id => vm_template.id, :boot_disk_size => ["10.GB", "10 GB"],
                            :placement_auto => [true, 1], :instance_type => [flavor.id, flavor.name]}
            2.times { create_request(@google_user1, @google_template, prov_options) }

            2.times { create_request(@google_user2, @google_template, prov_options) }
          end

          shared_examples_for "check_quota" do
            it "check" do
              create_requests
              stats = request.check_quota(quota_method)
              expect(stats).to include(counts_hash)
            end
          end

          context "active_provisions," do
            let(:request) { create_request(@vmware_user1, @vmware_template, {}) }
            let(:quota_method) { :active_provisions }
            let(:counts_hash) do
              {:count => 12, :memory => 8_589_938_688, :cpu => 32, :storage => 44.gigabytes}
            end
            it_behaves_like "check_quota"
          end

          context "infra," do
            let(:request) { create_request(@vmware_user1, @vmware_template, {}) }
            let(:counts_hash) do
              {:count => 8, :memory => 8.gigabytes, :cpu => 16, :storage => 4.gigabytes}
            end

            context "active_provisions_by_tenant," do
              let(:quota_method) { :active_provisions_by_tenant }
              it_behaves_like "check_quota"
            end

            context "active_provisions_by_group," do
              let(:quota_method) { :active_provisions_by_group }
              it_behaves_like "check_quota"
            end

            context "active_provisions_by_owner," do
              let(:quota_method) { :active_provisions_by_owner }
              let(:counts_hash) do
                {:count => 4, :memory => 4.gigabytes, :cpu => 8, :storage => 2.gigabytes}
              end
              it_behaves_like "check_quota"

              it "fails without owner_email option" do
                create_requests
                request.options = {}
                expect { request.check_quota(quota_method) }.to raise_error(NoMethodError)
              end
            end
          end

          context "cloud," do
            let(:request) { create_request(@google_user1, @google_template, {}) }
            let(:counts_hash) do
              {:count => 4, :memory => 4096, :cpu => 16, :storage => 40.gigabytes}
            end

            context "active_provisions_by_tenant," do
              let(:quota_method) { :active_provisions_by_tenant }
              it_behaves_like "check_quota"
            end

            context "active_provisions_by_group," do
              let(:quota_method) { :active_provisions_by_group }
              it_behaves_like "check_quota"
            end

            context "active_provisions_by_owner," do
              let(:quota_method) { :active_provisions_by_owner }
              let(:counts_hash) do
                {:count => 2, :memory => 2048, :cpu => 8, :storage => 20.gigabytes}
              end
              it_behaves_like "check_quota"
            end
          end
        end
      end

      context "when processing tags" do
        before { FactoryBot.create(:classification_department_with_tags) }

        it "should add and delete tags from a request" do
          expect(@pr.get_tags.length).to eq(0)

          t = Classification.is_category.where(:description => 'Department').includes(:tag).first
          @pr.add_tag(t.name, t.children.first.name)
          expect(@pr.get_tags[t.name.to_sym]).to be_kind_of(String) # Single tag returns as a String
          expect(@pr.get_tags[t.name.to_sym]).to eq(t.children.first.name)

          # Adding the same tag again should not increase the tag count
          @pr.add_tag(t.name, t.children.first.name)
          expect(@pr.get_tags[t.name.to_sym]).to be_kind_of(String) # Single tag returns as a String
          expect(@pr.get_tags[t.name.to_sym]).to eq(t.children.first.name)

          # Verify that #get_tag with classification returns the single child tag name
          expect(@pr.get_tags[t.name.to_sym]).to eq(@pr.get_tag(t.name))

          t.children.each { |c| @pr.add_tag(t.name, c.name) }
          expect(@pr.get_tags[t.name.to_sym]).to be_kind_of(Array)
          expect(@pr.get_tags[t.name.to_sym].length).to eq(t.children.length)

          child_names = t.children.collect(&:name)
          # Make sure each child name is yield from the tag method
          @pr.tags { |tag_name, _classification| child_names.delete(tag_name) }
          expect(child_names).to be_empty

          tags = @pr.get_classification(t.name)
          expect(tags).to be_kind_of(Array)
          classification = tags.first
          expect(classification).to be_kind_of(Hash)
          expect(classification.keys).to include(:name)
          expect(classification.keys).to include(:description)

          child_names = t.children.collect(&:name)

          @pr.clear_tag(t.name, child_names[0])
          expect(@pr.get_tags[t.name.to_sym]).to be_kind_of(Array) # Multiple tags return as an Array
          expect(@pr.get_tags[t.name.to_sym].length).to eq(t.children.length - 1)

          @pr.clear_tag(t.name, child_names[1])
          expect(@pr.get_tags[t.name.to_sym]).to be_kind_of(String) # Single tag returns as a String
          expect(@pr.get_tags[t.name.to_sym]).to eq(child_names[2])

          @pr.clear_tag(t.name)
          expect(@pr.get_tags[t.name.to_sym]).to be_nil # No tags returns as nil
          expect(@pr.get_tags.length).to eq(0)
        end

        it "should return classifications for tags" do
          expect(@pr.get_tags.length).to eq(0)

          t = Classification.is_category.where(:description => 'Department').includes(:tag).first
          @pr.add_tag(t.name, t.children.first.name)
          expect(@pr.get_tags[t.name.to_sym]).to be_kind_of(String)

          classification = @pr.get_classification(t.name)
          expect(classification).to be_kind_of(Hash)
          expect(classification.keys).to include(:name)
          expect(classification.keys).to include(:description)

          @pr.add_tag(t.name, t.children[1].name)
          expect(@pr.get_tags[t.name.to_sym]).to be_kind_of(Array)

          classification = @pr.get_classification(t.name)
          expect(classification).to be_kind_of(Array)
          first = classification.first
          expect(first.keys).to include(:name)
          expect(first.keys).to include(:description)
        end
      end
    end
  end
end
