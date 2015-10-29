require "spec_helper"

describe Metric::Processing do
  context ".process_derived_columns" do
    context "on :derived_host_sockets" do
      let(:hardware) { FactoryGirl.create(:hardware, :cpu_sockets => 2) }
      let(:host) { FactoryGirl.create(:host, :hardware => hardware) }

      it "adds the derived host sockets" do
        m = FactoryGirl.create(:metric_rollup_vm_hr, :resource => host)

        derived_columns = described_class.process_derived_columns(host, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_host_sockets]).to eq(2)
      end
    end

    context "on :derived_vm_numvcpus" do
      let(:vm) { FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :cpu_total_cores => 8)) }

      it "with all usage values" do
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usage_rate_average    => 50.0,
                               :cpu_usagemhz_rate_average => 1_500.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_numvcpus]).to eq 8
      end

      it "with only cpu_usage_rate_average usage value" do
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource               => vm,
                               :cpu_usage_rate_average => 50.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_numvcpus]).to eq 8
      end

      it "with only cpu_usagemhz_rate_average usage value" do
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usagemhz_rate_average => 1_500.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_numvcpus]).to eq 8
      end

      it "without usage values" do
        m = FactoryGirl.create(:metric_rollup_vm_hr, :resource => vm)

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_numvcpus]).to be_nil
      end

      it "without hardware" do
        vm = FactoryGirl.create(:vm_vmware)
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usage_rate_average    => 50.0,
                               :cpu_usagemhz_rate_average => 1_500.0
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_numvcpus]).to be_nil
      end
    end

    context "on :derived_cpu_available" do
      let(:vm) do
        FactoryGirl.create(:vm_vmware, :hardware =>
          FactoryGirl.create(:hardware,
                             :cpu_total_cores      => 8,
                             :cpu_sockets          => 4,
                             :cpu_cores_per_socket => 2,
                             :cpu_speed            => 3_000,
                            )
                          )
      end

      it "with all usage values" do
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usage_rate_average    => 50.0,
                               :cpu_usagemhz_rate_average => 1_500.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_cpu_available]).to eq 24_000.0
      end

      it "with only cpu_usage_rate_average usage value" do
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource               => vm,
                               :cpu_usage_rate_average => 50.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_cpu_available]).to eq 24_000
      end

      it "with only cpu_usagemhz_rate_average usage value" do
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usagemhz_rate_average => 1_500.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_cpu_available]).to eq 24_000
      end

      it "without usage values" do
        m = FactoryGirl.create(:metric_rollup_vm_hr, :resource => vm)

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_cpu_available]).to be_nil
      end

      it "without hardware" do
        vm = FactoryGirl.create(:vm_vmware)
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usage_rate_average    => 50.0,
                               :cpu_usagemhz_rate_average => 1_500.0
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_cpu_available]).to be_nil
      end
    end

    context "on :derived_memory_available" do
      let(:vm) do
        FactoryGirl.create(:vm_vmware, :hardware =>
          FactoryGirl.create(:hardware,
                             :memory_mb => 4_096
                            )
                          )
      end

      it "with usage values" do
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource                   => vm,
                               :mem_usage_absolute_average => 50.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_memory_available]).to eq 4_096
      end

      it "without usage values" do
        m = FactoryGirl.create(:metric_rollup_vm_hr, :resource => vm)

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_memory_available]).to be_nil
      end

      it "without hardware" do
        vm = FactoryGirl.create(:vm_vmware)
        m = FactoryGirl.create(:metric_rollup_vm_hr,
                               :resource                   => vm,
                               :mem_usage_absolute_average => 50.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_memory_available]).to be_nil
      end
    end
  end
end
