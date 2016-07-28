describe NumberOfVmsVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when the number of vms is greater than 1" do
      let(:number_of_vms) { 2 }

      context "when the platform is linux" do
        let(:platform) { "linux" }

        it "adds values to field names to hide and show" do
          expect(subject.determine_visibility(number_of_vms, platform)).to eq(
            :hide => [:sysprep_computer_name, :linux_host_name],
            :show => [:ip_addr]
          )
        end
      end

      context "when the platform is not linux" do
        let(:platform) { "not linux" }

        it "adds values to field names to hide and show" do
          expect(subject.determine_visibility(number_of_vms, platform)).to eq(
            :hide => [:sysprep_computer_name, :linux_host_name],
            :show => [:ip_addr]
          )
        end
      end
    end

    context "when the number of vms is not greater than 1" do
      let(:number_of_vms) { 1 }

      context "when the platform is linux" do
        let(:platform) { "linux" }

        it "adds values to field names to hide and show" do
          expect(subject.determine_visibility(number_of_vms, platform)).to eq(
            :hide => [:ip_addr, :sysprep_computer_name],
            :show => [:linux_host_name]
          )
        end
      end

      context "when the platform is not linux" do
        let(:platform) { "not linux" }

        it "adds values to field names to hide and show" do
          expect(subject.determine_visibility(number_of_vms, platform)).to eq(
            :hide => [:ip_addr, :linux_host_name],
            :show => [:sysprep_computer_name]
          )
        end
      end
    end
  end
end
