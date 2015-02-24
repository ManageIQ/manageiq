require "spec_helper"

describe EmsRefresh::Parsers::Vc do
  context ".vm_inv_to_hardware_hash" do
    context "properly calculates cores and sockets" do
      let(:inv) { {"summary" => {"config" => {"name" => "a"}}} }

      it("without total") { assert_cores_and_sockets_values(nil, nil, nil) }

      context "with total" do
        before { inv.store_path("summary", "config", "numCpu", "4") }

        it("total only") { assert_cores_and_sockets_values(4, 1, 4) }

        it "total and core count" do
          inv.store_path("config", "hardware", "numCoresPerSocket", "2")
          assert_cores_and_sockets_values(4, 2, 2)
        end
      end

      def assert_cores_and_sockets_values(total, cores, sockets)
        result = described_class.vm_inv_to_hardware_hash(inv)

        expect(result[:numvcpus]).to         eq(total)
        expect(result[:cores_per_socket]).to eq(cores)
        expect(result[:logical_cpus]).to     eq(sockets)
      end
    end
  end
end
