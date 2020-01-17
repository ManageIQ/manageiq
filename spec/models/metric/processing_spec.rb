RSpec.describe Metric::Processing do
  context "#add_missing_intervals" do
    let(:time_now) { Time.current }
    let(:last_perf) { FactoryBot.create(:metric_rollup_vm_hr, :timestamp => time_now) }
    let(:perf) { FactoryBot.create(:metric_rollup_vm_hr, :timestamp => time_now + 10_800) }
    context "#extrapolate" do
      it "fills all hourly intervals" do
        perf.save && last_perf.save
        expect(MetricRollup.count).to eq(2)
        described_class.send("extrapolate", MetricRollup, MetricRollup.all)
        expect(MetricRollup.count).to eq(3)
      end
    end

    context "#create_new_metric" do
      it "creates a filling record without ID attribute" do
        new_perf = described_class.send("create_new_metric", MetricRollup, last_perf, perf, 3600)
        expect(new_perf.id).to be_nil
      end

      it "averages the 2 metric values" do
        last_perf.derived_vm_numvcpus = 1000
        perf.derived_vm_numvcpus      = 2000
        new_perf = described_class.send("create_new_metric", MetricRollup, last_perf, perf, 3600)
        expect(new_perf.derived_vm_numvcpus).to eq(1500)
      end
    end
  end

  context ".process_derived_columns" do
    context "services" do
      let(:vm_amazon_a) { FactoryBot.create(:vm_amazon) }
      let(:vm_amazon_b) { FactoryBot.create(:vm_amazon, :powered_off) }
      let(:service) { FactoryBot.create(:service) }
      let(:metric_a) { FactoryBot.create(:metric_rollup_vm_hr, :resource => vm_amazon_a) }
      let(:metric_b) { FactoryBot.create(:metric_rollup_vm_hr, :resource => vm_amazon_b) }

      before do
        service.add_resource(vm_amazon_a)
        service.add_resource(vm_amazon_b)
        service.save
      end

      it "calculates derived values" do
        derived_columns = described_class.process_derived_columns(service, metric_a.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_count_on]).to eq(1)
        expect(derived_columns[:derived_vm_count_off]).to eq(1)
        expect(derived_columns[:derived_vm_count_total]).to eq(2)
      end
    end

    context "on :derived_host_sockets" do
      let(:hardware) { FactoryBot.create(:hardware, :cpu_sockets => 2) }
      let(:host) { FactoryBot.create(:host, :hardware => hardware) }

      it "adds the derived host sockets" do
        m = FactoryBot.create(:metric_rollup_vm_hr, :resource => host)

        derived_columns = described_class.process_derived_columns(host, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_host_sockets]).to eq(2)
      end
    end

    context "on :derived_vm_numvcpus" do
      let(:vm) { FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :cpu_total_cores => 8)) }

      it "with all usage values" do
        m = FactoryBot.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usage_rate_average    => 50.0,
                               :cpu_usagemhz_rate_average => 1_500.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_numvcpus]).to eq 8
      end

      it "with only cpu_usage_rate_average usage value" do
        m = FactoryBot.create(:metric_rollup_vm_hr,
                               :resource               => vm,
                               :cpu_usage_rate_average => 50.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_numvcpus]).to eq 8
      end

      it "with only cpu_usagemhz_rate_average usage value" do
        m = FactoryBot.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usagemhz_rate_average => 1_500.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_numvcpus]).to eq 8
      end

      it "without usage values" do
        m = FactoryBot.create(:metric_rollup_vm_hr, :resource => vm)

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_vm_numvcpus]).to be_nil
      end

      it "without hardware" do
        vm = FactoryBot.create(:vm_vmware)
        m = FactoryBot.create(:metric_rollup_vm_hr,
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
        FactoryBot.create(:vm_vmware, :hardware =>
          FactoryBot.create(:hardware,
                             :cpu_total_cores      => 8,
                             :cpu_sockets          => 4,
                             :cpu_cores_per_socket => 2,
                             :cpu_speed            => 3_000,
                            )
                          )
      end

      it "with all usage values" do
        m = FactoryBot.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usage_rate_average    => 50.0,
                               :cpu_usagemhz_rate_average => 1_500.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_cpu_available]).to eq 24_000.0
      end

      it "with only cpu_usage_rate_average usage value" do
        m = FactoryBot.create(:metric_rollup_vm_hr,
                               :resource               => vm,
                               :cpu_usage_rate_average => 50.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_cpu_available]).to eq 24_000
      end

      it "with only cpu_usagemhz_rate_average usage value" do
        m = FactoryBot.create(:metric_rollup_vm_hr,
                               :resource                  => vm,
                               :cpu_usagemhz_rate_average => 1_500.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_cpu_available]).to eq 24_000
      end

      it "without usage values" do
        m = FactoryBot.create(:metric_rollup_vm_hr, :resource => vm)

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_cpu_available]).to be_nil
      end

      it "without hardware" do
        vm = FactoryBot.create(:vm_vmware)
        m = FactoryBot.create(:metric_rollup_vm_hr,
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
        FactoryBot.create(:vm_vmware, :hardware =>
          FactoryBot.create(:hardware,
                             :memory_mb => 4_096
                            )
                          )
      end

      it "with usage values" do
        m = FactoryBot.create(:metric_rollup_vm_hr,
                               :resource                   => vm,
                               :mem_usage_absolute_average => 50.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_memory_available]).to eq 4_096
      end

      it "without usage values" do
        m = FactoryBot.create(:metric_rollup_vm_hr, :resource => vm)

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_memory_available]).to be_nil
      end

      it "without hardware" do
        vm = FactoryBot.create(:vm_vmware)
        m = FactoryBot.create(:metric_rollup_vm_hr,
                               :resource                   => vm,
                               :mem_usage_absolute_average => 50.0,
                              )

        derived_columns = described_class.process_derived_columns(vm, m.attributes.symbolize_keys)

        expect(derived_columns[:derived_memory_available]).to be_nil
      end
    end
  end
end
