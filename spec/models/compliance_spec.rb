describe Compliance do
  context "A small virtual infrastructure" do
    let(:ems_vmware) { FactoryGirl.create(:ems_vmware, :zone => zone) }
    let(:host1)      { FactoryGirl.create(:host, :ext_management_system => ems_vmware) }
    let(:host2)      { FactoryGirl.create(:host) }
    let(:vm1)        { FactoryGirl.create(:vm_vmware, :host => host1, :ext_management_system => ems_vmware) }
    let(:zone)       { FactoryGirl.build(:zone) }

    before { allow(MiqServer).to receive(:my_zone).and_return(zone) }

    context(".check_compliance_queue") do
      it "for single vm" do
        create_check_compliance_queue_expections(vm1)

        Compliance.check_compliance_queue(vm1)
      end

      it "for single vm via vm method" do
        create_check_compliance_queue_expections(vm1)

        vm1.check_compliance_queue
      end

      it "for single host" do
        create_check_compliance_queue_expections(host1)

        Compliance.check_compliance_queue(host1)
      end

      it "for single host via host method" do
        create_check_compliance_queue_expections(host1)

        host1.check_compliance_queue
      end

      it "for multiple objects" do
        subject = [vm1, host1]
        create_check_compliance_queue_expections(*subject)

        Compliance.check_compliance_queue(subject)
      end

      it "for multiple objects with inputs" do
        inputs = {:foo => 'bar'}
        subject = [vm1, host1]
        create_check_compliance_queue_expections(*subject, inputs)

        Compliance.check_compliance_queue(subject, inputs)
      end
    end

    context ".scan_and_check_compliance_queue" do
      it "should queue single host for scan_and_check_compliance via host method" do
        create_scan_and_check_compliance_queue_expections(host1)

        host1.scan_and_check_compliance_queue
      end

      it "should queue multiple objects for scan_and_check_compliance" do
        create_scan_and_check_compliance_queue_expections(host1, host2)

        Compliance.scan_and_check_compliance_queue([vm1, host1, host2])
      end

      it "should queue multiple objects for scan_and_check_compliance with inputs" do
        inputs = {:foo => 'bar'}
        create_scan_and_check_compliance_queue_expections(host1, host2, inputs)

        Compliance.scan_and_check_compliance_queue([vm1, host1, host2], inputs)
      end
    end

    context ".scan_and_check_compliance" do
      it "should raise event request_host_scan" do
        expect(MiqEvent).to receive(:raise_evm_event).with(host1, "request_host_scan", {}, {})
        Compliance.scan_and_check_compliance([host1.class.name, host1.id])
      end
    end

    context ".check_compliance" do
      shared_examples ".check_compliance" do
        let(:policy)     { FactoryGirl.create(:miq_policy, :mode => 'compliance', :towhat => 'Vm', :active => true) }
        let(:policy_set) { FactoryGirl.create(:miq_policy_set) }
        let(:template)   { FactoryGirl.create(:template_vmware, :host => host1, :ext_management_system => ems_vmware) }

        before do
          policy.sync_events([FactoryGirl.create(:miq_event_definition, :name => "vm_compliance_check")])
          policy.conditions << FactoryGirl.create(:condition, :expression => MiqExpression.new("IS NOT EMPTY" => {"field" => "Vm-id"}))
          policy_set.add_member(policy)
          ems_vmware.add_policy(policy_set)
        end

        it "compliant" do
          expect(MiqEvent).to receive(:raise_evm_event_queue).with(subject, "vm_compliance_passed")
          expect(Compliance.check_compliance(subject)).to be_truthy
        end

        it "non-compliant" do
          policy.conditions << FactoryGirl.create(:condition, :expression => MiqExpression.new(">=" => {"field" => "Vm-num_cpu", "value" => "2"}))

          expect(MiqEvent).to receive(:raise_evm_event_queue).with(subject, "vm_compliance_failed")
          expect(Compliance.check_compliance(subject)).to be_falsey
        end
      end

      context "VM" do
        subject { vm1 }
        include_examples ".check_compliance"
      end

      context "template" do
        subject { template }
        include_examples ".check_compliance"
      end
    end
  end

  private

  def create_check_compliance_queue_expections(*objects)
    inputs = objects.extract_options!
    objects.each do |obj|
      expect(MiqQueue).to receive(:put) do |args|
        expect(args).to have_attributes(
          :method_name => "check_compliance",
          :class_name  => "Compliance",
          :args        => [[obj.class.name, obj.id], inputs]
        )
      end
    end
  end

  def create_scan_and_check_compliance_queue_expections(*objects)
    inputs = objects.extract_options!
    objects.each do |obj|
      expect(MiqQueue).to receive(:put) do |args|
        expect(args).to have_attributes(
          :method_name => "scan_and_check_compliance",
          :class_name  => "Compliance",
          :task_id     => 'vc-refresher',
          :role        => 'ems_inventory',
          :args        => [[obj.class.name, obj.id], inputs]
        )
      end
    end
  end
end
