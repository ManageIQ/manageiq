describe ConversionHost do
  let(:apst) { FactoryGirl.create(:service_template_ansible_playbook) }

  context "provider independent methods" do
    let(:host) { FactoryGirl.create(:host) }
    let(:vm) { FactoryGirl.create(:vm_or_template) }
    let(:conversion_host_1) { FactoryGirl.create(:conversion_host, :resource => host) }
    let(:conversion_host_2) { FactoryGirl.create(:conversion_host, :resource => vm) }
    let(:task_1) { FactoryGirl.create(:service_template_transformation_plan_task, :state => 'active', :conversion_host => conversion_host_1) }
    let(:task_2) { FactoryGirl.create(:service_template_transformation_plan_task, :conversion_host => conversion_host_1) }
    let(:task_3) { FactoryGirl.create(:service_template_transformation_plan_task, :state => 'active', :conversion_host => conversion_host_2) }

    before do
      conversion_host_1.concurrent_transformation_limit = "2"
      conversion_host_2.concurrent_transformation_limit = "1"

      allow(ServiceTemplateTransformationPlanTask).to receive(:where).with(:state => 'active').and_return([task_1, task_3])
    end

    it "#active_tasks" do
      expect(conversion_host_1.active_tasks).to eq([task_1])
      expect(conversion_host_2.active_tasks).to eq([task_3])
    end

    it "#eligible?" do
      expect(conversion_host_1.eligible?).to eq(true)
      expect(conversion_host_2.eligible?).to eq(false)
    end

    context "#source_transport_method" do
      it { expect(conversion_host_2.source_transport_method).to be_nil }

      context "ssh transport enabled" do
        before { conversion_host_2.ssh_transport_supported = true }
        it { expect(conversion_host_2.source_transport_method).to eq('ssh') }

        context "vddk transport enabled" do
          before { conversion_host_2.vddk_transport_supported = true }
          it { expect(conversion_host_2.source_transport_method).to eq('vddk') }
        end
      end
    end
  end
end
