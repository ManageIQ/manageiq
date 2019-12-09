RSpec.describe VmOrTemplate::Operations::Relocation do
  let(:ems)  { FactoryBot.create(:ems_openstack) }
  let(:vm)   { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }

  context "queued methods" do
    it 'queues an update task with update_volume_queue' do
      options = {:name => 'updated_vm_name'}
      task_id = vm.evacuate_queue(user.userid, options)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "evacuating VM for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => vm.class.name).first).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => 'evacuate',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => [options]
      )
    end
  end
end
