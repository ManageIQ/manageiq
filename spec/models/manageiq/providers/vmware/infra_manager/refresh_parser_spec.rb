require "spec_helper"

describe ManageIQ::Providers::Vmware::InfraManager::RefreshParser do
  context ".vm_inv_to_hardware_hash" do
    context "properly calculates cores and sockets" do
      let(:inv) { {"summary" => {"config" => {"name" => "a"}}} }

      it("without total") { assert_cores_and_sockets_values(nil, nil, nil) }

      context "with total" do
        before { inv.store_path("summary", "config", "numCpu", "8") }

        it("total only") { assert_cores_and_sockets_values(8, 1, 8) }

        it "total and core count" do
          inv.store_path("config", "hardware", "numCoresPerSocket", "2")
          assert_cores_and_sockets_values(8, 2, 4)
        end
      end

      def assert_cores_and_sockets_values(total, cores, sockets)
        result = described_class.vm_inv_to_hardware_hash(inv)

        expect(result[:numvcpus]).to             eq(sockets)
        expect(result[:cpu_cores_per_socket]).to eq(cores)
        expect(result[:logical_cpus]).to         eq(total)
      end
    end
  end
end
