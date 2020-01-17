RSpec.describe Metric::CiMixin do
  context "with a Vm" do
    let(:vm) { FactoryBot.create(:vm_vmware) }

    context "#has_perf_data?" do
      it "without data" do
        expect(vm.has_perf_data?).to be_falsey
      end

      it "with data" do
        FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => Time.now.utc)
        expect(vm.has_perf_data?).to be_truthy
      end
    end

    context "#last_capture" do
      it "without data" do
        expect(vm.last_capture).to be_nil
      end

      it "with data" do
        FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => 10.minutes.ago.utc)
        FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => 5.minutes.ago.utc)
        last = FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => Time.now.utc)
        expect(vm.last_capture).to be_within(0.1).of last.timestamp
      end
    end

    context "#first_capture" do
      it "without data" do
        expect(vm.first_capture).to be_nil
      end

      it "with data" do
        first = FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => 10.minutes.ago.utc)
        FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => 5.minutes.ago.utc)
        FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => Time.now.utc)
        expect(vm.first_capture).to be_within(0.1).of first.timestamp
      end
    end

    context "#first_and_last_capture" do
      it "without data" do
        expect(vm.first_and_last_capture).to eq([])
      end

      it "with one record" do
        first = FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => Time.now.utc)
        actual = vm.first_and_last_capture
        expect(actual.length).to eq(2)
        expect(actual[0]).to be_within(0.1).of first.timestamp
        expect(actual[1]).to be_within(0.1).of first.timestamp
      end

      it "with multiple records" do
        first = FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => 10.minutes.ago.utc)
        FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => 5.minutes.ago.utc)
        last = FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :timestamp => Time.now.utc)
        actual = vm.first_and_last_capture
        expect(actual.length).to eq(2)
        expect(actual[0]).to be_within(0.1).of first.timestamp
        expect(actual[1]).to be_within(0.1).of last.timestamp
      end
    end
  end

  context "#supports_capture?" do
    context "with a VM" do
      let(:unsupported_vm) { FactoryBot.create(:vm_microsoft) }
      let(:supported_vm)   { FactoryBot.create(:vm_vmware) }

      it "correctly checks capture support" do
        expect(unsupported_vm.supports_capture?).to be_falsy
        expect(supported_vm.supports_capture?).to be_truthy
      end
    end

    context "with a Host" do
      let(:unsupported_host) { FactoryBot.create(:host_microsoft) }
      let(:supported_host)   { FactoryBot.create(:vm_vmware) }

      it "correctly checks capture support" do
        expect(unsupported_host.supports_capture?).to be_falsy
        expect(supported_host.supports_capture?).to be_truthy
      end
    end
  end
end
