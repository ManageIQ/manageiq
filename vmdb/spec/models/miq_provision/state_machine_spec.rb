require "spec_helper"

describe MiqProvision do
  context "::StateMachine" do
    let(:ems)      { FactoryGirl.create(:ems_openstack_with_authentication) }
    let(:flavor)   { FactoryGirl.create(:flavor_openstack, :ems_ref => 24) }
    let(:options)  { {:src_vm_id => template.id, :vm_target_name => "test_vm_1"} }
    let(:template) { FactoryGirl.create(:template_openstack, :ext_management_system => ems, :ems_ref => MiqUUID.new_guid) }
    let(:vm)       { FactoryGirl.create(:vm_openstack) }

    let(:task)     { FactoryGirl.create(:miq_provision_openstack, :source => template, :destination => vm, :state => 'pending', :status => 'Ok', :options => options) }

    context "#prepare_provision" do
      before do
        task.stub(:update_and_notify_parent)
        task.stub(:instance_type => flavor)
      end

      it "sets default :clone_options" do
        task.should_receive(:signal).with(:prepare_provision).and_call_original
        task.should_receive(:signal).with(:start_clone_task)

        task.signal(:prepare_provision)

        expect(task.phase_context[:clone_options]).to eq(
          :flavor_ref      => flavor.ems_ref,
          :image_ref       => template.ems_ref,
          :name            => options[:vm_target_name],
          :security_groups => [],
        )
      end

      it "merges :clone_options from automate" do
        options[:clone_options] = {:security_groups => ["test_sg"], :test_key => "test_value"}
        task.update_attributes(:options => options)

        task.should_receive(:signal).with(:prepare_provision).and_call_original
        task.should_receive(:signal).with(:start_clone_task)

        task.signal(:prepare_provision)

        expect(task.phase_context[:clone_options]).to eq(
          :flavor_ref      => flavor.ems_ref,
          :image_ref       => template.ems_ref,
          :name            => options[:vm_target_name],
          :security_groups => ["test_sg"],
          :test_key        => "test_value"
        )
      end
    end

    context "#post_create_destination" do
      let(:user) { FactoryGirl.create(:user, :email => "foo@example.com") }

      it "sets description" do
        options[:vm_description] = description = "foo bar"
        task.update_attributes(:options => options)

        task.should_receive(:mark_as_completed)

        task.signal(:post_create_destination)

        expect(task.destination.description).to eq(description)
        expect(vm.reload.description).to        eq(description)
      end

      it "sets ownership" do
        options[:owner_email] = user.email
        task.update_attributes(:options => options)

        task.stub(:miq_request => double("MiqRequest").as_null_object)

        task.should_receive(:mark_as_completed)

        task.signal(:post_create_destination)

        expect(task.destination.evm_owner).to eq(user)
        expect(vm.reload.evm_owner).to        eq(user)
      end

      context "sets retirement" do
        it "with :retirement option" do
          options[:retirement] = retirement = 2.days.to_i
          retires_on           = (Time.now.utc + retirement).to_date
          task.update_attributes(:options => options)

          task.should_receive(:mark_as_completed)

          task.signal(:post_create_destination)

          expect(task.destination.retires_on).to eq(retires_on)
          expect(vm.reload.retires_on).to        eq(retires_on)
          expect(vm.retirement_warn).to          eq(0)
          expect(vm.retired).to                  be_false
        end

        it "with :retirement_time option" do
          retirement_warn_days      = 7
          options[:retirement]      = 2.days.to_i
          options[:retirement_time] = retirement_time = Time.now.utc + 3.days  # This setting overrides the :retirement setting
          options[:retirement_warn] = retirement_warn_days.days.to_i
          retires_on                = retirement_time.to_date
          task.update_attributes(:options => options)

          task.should_receive(:mark_as_completed)

          task.signal(:post_create_destination)

          expect(task.destination.retires_on).to eq(retires_on)
          expect(vm.reload.retires_on).to        eq(retires_on)
          expect(vm.retirement_warn).to          eq(retirement_warn_days)
          expect(vm.retired).to                  be_false
        end
      end

      it "sets genealogy" do
        task.should_receive(:mark_as_completed)

        task.signal(:post_create_destination)

        task.destination.with_relationship_type("genealogy") { |v| expect(v.parent).to   eq(template) }
        vm.reload.with_relationship_type("genealogy")        { |v| expect(v.parent).to   eq(template) }
        template.reload.with_relationship_type("genealogy")  { |v| expect(v.children).to eq([vm]) }
      end
    end
  end
end
