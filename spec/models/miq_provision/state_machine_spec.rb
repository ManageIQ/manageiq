RSpec.describe MiqProvision do
  context "::StateMachine" do
    let(:req_user) { FactoryBot.create(:user_with_group) }
    let(:ems)      { FactoryBot.create(:ems_openstack_with_authentication) }
    let(:flavor)   { FactoryBot.create(:flavor_openstack, :ems_ref => 24) }
    let(:options)  { {:src_vm_id => template.id, :vm_target_name => "test_vm_1"} }
    let(:template) { FactoryBot.create(:template_openstack, :ext_management_system => ems, :ems_ref => SecureRandom.uuid) }
    let(:vm)       { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }

    let(:task) do
      FactoryBot.create(:miq_provision_openstack,
                         :source      => template,
                         :destination => vm,
                         :state       => 'pending',
                         :status      => 'Ok',
                         :userid      => req_user.userid,
                         :options     => options)
    end

    context "#prepare_provision" do
      before do
        allow(task).to receive(:update_and_notify_parent)
        allow(task).to receive_messages(:instance_type => flavor)
      end

      it "sets default :clone_options" do
        expect(task).to receive(:signal).with(:prepare_provision).and_call_original
        expect(task).to receive(:signal).with(:start_clone_task)

        task.signal(:prepare_provision)

        expect(task.phase_context[:clone_options]).to eq(
          :flavor_ref      => flavor.ems_ref,
          :image_ref       => template.ems_ref,
          :name            => options[:vm_target_name],
          :security_groups => []
        )
      end

      it "merges :clone_options from automate" do
        options[:clone_options] = {:security_groups => ["test_sg"], :test_key => "test_value"}
        task.update(:options => options)

        expect(task).to receive(:signal).with(:prepare_provision).and_call_original
        expect(task).to receive(:signal).with(:start_clone_task)

        task.signal(:prepare_provision)

        expect(task.phase_context[:clone_options]).to eq(
          :flavor_ref      => flavor.ems_ref,
          :image_ref       => template.ems_ref,
          :name            => options[:vm_target_name],
          :security_groups => ["test_sg"],
          :test_key        => "test_value"
        )
      end

      it "handles deleting nils when merging :clone_options from automate" do
        options[:clone_options] = {:image_ref => nil, :test_key => "test_value"}
        task.update(:options => options)

        expect(task).to receive(:signal).with(:prepare_provision).and_call_original
        expect(task).to receive(:signal).with(:start_clone_task)

        task.signal(:prepare_provision)

        expect(task.phase_context[:clone_options]).to eq(
          :flavor_ref      => flavor.ems_ref,
          :name            => options[:vm_target_name],
          :security_groups => [],
          :test_key        => "test_value"
        )
      end
    end

    context "#post_create_destination" do
      let(:user) { FactoryBot.create(:user_with_email_and_group) }

      it "sets description" do
        options[:vm_description] = description = "foo bar"
        task.update(:options => options)

        expect(task).to receive(:mark_as_completed)

        task.signal(:post_create_destination)

        expect(task.destination.description).to eq(description)
        expect(vm.reload.description).to        eq(description)
      end

      context "sets ownership" do
        let(:group_user)  { FactoryBot.create(:miq_group, :description => "user_group") }
        let(:group_admin) { FactoryBot.create(:miq_group, :description => "admin_group") }

        it "sets the destination group from owner_group" do
          user.update!(:miq_groups => [group_user, group_admin], :current_group => group_user)
          options[:owner_email] = user.email
          options[:owner_group] = group_user.description
          task.update(:options => options)

          expect(task).to receive(:mark_as_completed)
          task.signal(:post_create_destination)

          expect(vm.reload.evm_owner).to eq(user)
          expect(vm.miq_group).to eq(group_user)
        end

        it "sets the destination group from owner_group even if the user changed active group to admin" do
          user.update!(:miq_groups => [group_user, group_admin], :current_group => group_admin)
          options[:owner_email] = user.email
          options[:owner_group] = group_user.description
          task.update(:options => options)

          expect(task).to receive(:mark_as_completed)
          task.signal(:post_create_destination)

          expect(vm.reload.evm_owner).to eq(user)
          expect(vm.miq_group).to eq(group_user)
        end

        it "sets the destination group from owner_group even if the user changed active group to user" do
          user.update!(:miq_groups => [group_user, group_admin], :current_group => group_user)
          options[:owner_email] = user.email
          options[:owner_group] = group_admin.description
          task.update(:options => options)

          expect(task).to receive(:mark_as_completed)
          task.signal(:post_create_destination)

          expect(vm.reload.evm_owner).to eq(user)
          expect(vm.miq_group).to eq(group_admin)
        end

        it "falls back to requester_group when owner_group is absent and the user switched to a different active group before provision" do
          user.update!(:miq_groups => [group_user, group_admin], :current_group => group_admin)
          options[:owner_email] = user.email
          task.update(:userid => user.userid, :options => options.merge(:requester_group => group_user.description))

          expect(task).to receive(:mark_as_completed)
          task.signal(:post_create_destination)

          expect(vm.reload.evm_owner).to eq(user)
          expect(vm.miq_group).to eq(group_user)
        end

        it "falls back to requester_group when owner_group is absent and the user switched to a different active group before provision (reversed groups)" do
          user.update!(:miq_groups => [group_user, group_admin], :current_group => group_user)
          options[:owner_email] = user.email
          task.update(:userid => user.userid, :options => options.merge(:requester_group => group_admin.description))

          expect(task).to receive(:mark_as_completed)
          task.signal(:post_create_destination)

          expect(vm.reload.evm_owner).to eq(user)
          expect(vm.miq_group).to eq(group_admin)
        end

        # No owner_email means get_user is called instead of get_owner.
        it "falls back to requester_group when neither owner_email nor owner_group is set and the user changed active group before provision" do
          user.update!(:miq_groups => [group_user, group_admin], :current_group => group_admin)
          task.update(:userid => user.userid, :options => options.merge(:requester_group => group_user.description))

          expect(task).to receive(:mark_as_completed)
          task.signal(:post_create_destination)

          expect(vm.reload.evm_owner).to eq(user)
          expect(vm.miq_group).to eq(group_user)
        end
      end

      context "sets retirement" do
        it "with :retirement option" do
          options[:retirement] = retirement = 2.days.to_i
          retires_on           = Time.now.utc + retirement
          task.update(:options => options)

          expect(task).to receive(:mark_as_completed)

          task.signal(:post_create_destination)

          expect(task.destination.retires_on).to be_between(retires_on - 2.seconds, retires_on + 2.seconds)
          expect(vm.reload.retires_on).to        be_between(retires_on - 2.seconds, retires_on + 2.seconds)
          expect(vm.retirement_warn).to          eq(0)
          expect(vm.retired).to                  be_falsey
        end

        it "with :retirement_time option" do
          retirement_warn_days      = 7
          options[:retirement]      = 2.days.to_i
          options[:retirement_time] = retirement_time = Time.now.utc + 3.days  # This setting overrides the :retirement setting
          options[:retirement_warn] = retirement_warn_days.days.to_i
          retires_on                = retirement_time
          task.update(:options => options)

          expect(task).to receive(:mark_as_completed)

          task.signal(:post_create_destination)

          expect(task.destination.retires_on).to eq(retires_on)
          expect(vm.reload.retires_on).to        be_between(retires_on - 2.seconds, retires_on + 2.seconds)
          expect(vm.retirement_warn).to          eq(retirement_warn_days)
          expect(vm.retired).to                  be_falsey
        end
      end

      it "sets genealogy" do
        expect(task).to receive(:mark_as_completed)

        task.signal(:post_create_destination)

        task.destination.with_relationship_type("genealogy") { |v| expect(v.parent).to   eq(template) }
        vm.reload.with_relationship_type("genealogy")        { |v| expect(v.parent).to   eq(template) }
        template.reload.with_relationship_type("genealogy")  { |v| expect(v.children).to eq([vm]) }
      end
    end
  end
end
