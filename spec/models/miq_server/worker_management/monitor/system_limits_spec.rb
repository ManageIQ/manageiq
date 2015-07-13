require 'spec_helper'

describe MiqServer do
  context "WorkerManagement::Monitor::SystemLimits" do
    before do
      _, @server, _ = EvmSpecHelper.create_guid_miq_server_zone
      @monitor_settings = YAML.load(<<-EOS
        :kill_algorithm:
          :name: :used_swap_percent_gt_value
          :value: 80
        :start_algorithm:
          :name: :used_swap_percent_lt_value
          :value: 60
        EOS
      )

      @server.stub(:worker_monitor_settings => @monitor_settings)
      @server.stub(:child_worker_settings => {:generic_worker => {}})
      @memory_usage = {:MemFree => 0.megabytes, :SwapTotal => 10.gigabytes, :SwapFree => 3.gigabytes}
    end

    context "used_swap_percent_lt_value" do
      context "#enough_resource_to_start_worker?" do
        it "70% swap used" do
          MiqSystem.stub(:memory => @memory_usage.merge(:SwapFree => 3.gigabytes))
          expect(@server.enough_resource_to_start_worker?(MiqGenericWorker)).to be_false
        end

        it "30% swap used" do
          MiqSystem.stub(:memory => @memory_usage.merge(:SwapFree => 7.gigabytes))
          expect(@server.enough_resource_to_start_worker?(MiqGenericWorker)).to be_true
        end

        it "child_worker_settings overrides worker_monitor_settings" do
          child = YAML.load(<<-EOS
            :generic_worker:
              :start_algorithm:
                :name: :used_swap_percent_lt_value
                :value: 20
            EOS
          )
          @server.stub(:child_worker_settings => child)

          MiqSystem.stub(:memory => @memory_usage.merge(:SwapFree => 7.gigabytes))
          expect(@server.enough_resource_to_start_worker?(MiqGenericWorker)).to be_false
        end
      end

      context "#kill_workers_due_to_resources_exhausted?" do
        it "90% swap used" do
          MiqSystem.stub(:memory => @memory_usage.merge(:SwapFree => 1.gigabytes))
          expect(@server.kill_workers_due_to_resources_exhausted?).to be_true
        end

        it "70% swap used" do
          MiqSystem.stub(:memory => @memory_usage.merge(:SwapFree => 3.gigabytes))
          expect(@server.kill_workers_due_to_resources_exhausted?).to be_false
        end
      end
    end
  end
end
