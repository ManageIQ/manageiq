shared_examples_for "AggregationMixin" do |through|
  context "includes AggregationMixin" do
    include Spec::Support::ArelHelper

    let(:hardware) do
      FactoryBot.create(:hardware,
                        :cpu2x2,
                        :ram1GB,
                        :cpu_speed     => 2_999,
                        :disk_capacity => 40,
                        :memory_mb     => 2048)
    end

    let(:ems) { FactoryBot.create(:ext_management_system) }
    let!(:vm) { FactoryBot.create(:vm, :hardware => hardware, :ext_management_system => ems) }
    let!(:vm1) { FactoryBot.create(:vm, :hardware => hardware, :ext_management_system => ems) }
    let!(:host) { FactoryBot.create(:host, :hardware => hardware, :ext_management_system => ems) }
    let!(:host1) { FactoryBot.create(:host, :hardware => hardware, :ext_management_system => ems) }
    let(:object) { FactoryBot.create(described_class.to_s.underscore.to_sym) }

    before do
      if through == "ext_management_systems"
        object.ext_management_systems << ems
      elsif through == "computer_systems"
        object.computer_system_hardwares << [hardware]
      elsif described_class == Host
        object.host_hardwares << [hardware]
        object.vms_and_templates << [vm, vm1]
      else
        object.hosts << [host, host1]
        object.vms_and_templates << [vm, vm1]
      end
    end

    describe "calculates single object" do
      context "host" do
        it "calculates #aggregate_cpu_speed" do
          expect { expect(object.aggregate_cpu_speed).to eq(11_996) }.to make_database_queries(:count => 0..1)
        end

        it "calculates #aggregate_cpu_total_cores" do
          expect { expect(object.aggregate_cpu_total_cores).to eq(4) }.to make_database_queries(:count => 0..1)
        end

        it "calculates #aggregate_disk_capacity" do
          expect { expect(object.aggregate_disk_capacity).to eq(0.4e2) }.to make_database_queries(:count => 0..1)
        end

        it "calculates #aggregate_memory" do
          expect { expect(object.aggregate_memory).to eq(2048) }.to make_database_queries(:count => 0..1)
        end

        it "calculates #aggregate_physical_cpus" do
          expect { expect(object.aggregate_physical_cpus).to eq(2) }.to make_database_queries(:count => 0..1)
        end
      end

      context "vm" do
        it "calculates #aggregate_vm_memory" do
          expect { expect(object.aggregate_vm_memory).to eq(2048) }.to make_database_queries(:count => 0..1)
        end

        it "calculates #aggregate_vm_cpus" do
          expect { expect(object.aggregate_vm_cpus).to eq(2) }.to make_database_queries(:count => 0..1)
        end
      end
    end
  end
end
