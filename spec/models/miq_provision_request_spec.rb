describe MiqProvisionRequest do
  it ".request_task_class_from" do
    ems = FactoryGirl.create(:ems_vmware)
    vm = FactoryGirl.create(:vm_vmware, :ext_management_system => ems)
    expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id})).to eq ManageIQ::Providers::Vmware::InfraManager::Provision
    expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id, :provision_type => "pxe"})).to eq ManageIQ::Providers::Vmware::InfraManager::ProvisionViaPxe

    ems = FactoryGirl.create(:ems_redhat)
    vm = FactoryGirl.create(:vm_redhat, :ext_management_system => ems)
    expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id})).to eq ManageIQ::Providers::Redhat::InfraManager::Provision

    ems = FactoryGirl.create(:ems_openstack)
    vm = FactoryGirl.create(:vm_openstack, :ext_management_system => ems)
    expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id})).to eq ManageIQ::Providers::Openstack::CloudManager::Provision

    ems = FactoryGirl.create(:ems_amazon)
    vm = FactoryGirl.create(:vm_amazon, :ext_management_system => ems)
    expect(described_class.request_task_class_from('options' => {:src_vm_id => vm.id})).to eq ManageIQ::Providers::Amazon::CloudManager::Provision
  end

  context "A new provision request," do
    before            { allow_any_instance_of(User).to receive(:role).and_return("admin") }
    let(:approver)    { FactoryGirl.create(:user_miq_request_approver) }
    let(:user)        { FactoryGirl.create(:user) }
    let(:ems)         { FactoryGirl.create(:ems_vmware) }
    let(:vm)          { FactoryGirl.create(:vm_vmware, :name => "vm1", :location => "abc/def.vmx") }
    let(:vm_template) { FactoryGirl.create(:template_vmware, :name => "template1", :ext_management_system => ems) }

    it "should not be created without requester being specified" do
      expect { FactoryGirl.create(:miq_provision_request) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should not be created with an invalid userid being specified" do
      expect { FactoryGirl.create(:miq_provision_request, :userid => 'barney', :src_vm_id => vm_template.id) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should not be created with a valid userid but no vm being specified" do
      expect { FactoryGirl.create(:miq_provision_request, :requester => user) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should be created from either a VM or Template" do
      expect { FactoryGirl.create(:miq_provision_request, :requester => user, :src_vm_id => vm_template.id) }.not_to raise_error
      expect { FactoryGirl.create(:miq_provision_request, :requester => user, :src_vm_id => vm.id) }.not_to raise_error
    end

    it "should not be created with a valid userid but invalid vm being specified" do
      expect { FactoryGirl.create(:miq_provision_request, :requester => user, :src_vm_id => 42) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    context "with a valid userid and source vm," do
      before do
        @pr = FactoryGirl.create(:miq_provision_request, :requester => user, :src_vm_id => vm_template.id, :options => {:owner_email => 'tester@miq.com'})
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
          prov_options = {:number_of_vms => [2, '2'], :owner_email => 'tester@miq.com', :vm_memory => ['1024', '1024'], :number_of_cpus => [2, '2']}
          @pr2 = FactoryGirl.create(:miq_provision_request, :requester => user, :src_vm_id => vm_template.id, :options => prov_options)

          stats = @pr.check_quota(:requests_by_owner)
          expect(stats).to be_kind_of(Hash)

          expect(stats[:class_name]).to eq("MiqProvisionRequest")
          expect(stats[:count]).to eq(2)
          expect(stats[:memory]).to eq(2048)
          expect(stats[:cpu]).to eq(4)
          expect(stats.fetch_path(:active, :class_name)).to eq("MiqProvision")
        end
      end

      context "when processing tags" do
        before { FactoryGirl.create(:classification_department_with_tags) }

        it "should add and delete tags from a request" do
          expect(@pr.get_tags.length).to eq(0)

          t = Classification.where(:description => 'Department', :parent_id => 0).includes(:tag).first
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

          t = Classification.where(:description => 'Department', :parent_id => 0).includes(:tag).first
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
