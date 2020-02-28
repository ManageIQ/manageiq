describe PxeIsoVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when pxe is supported" do
      let(:supports_pxe) { true }

      context "when iso is supported" do
        let(:supports_iso) { true }

        it "returns the values to be edit and hidden" do
          expect(subject.determine_visibility(supports_iso, supports_pxe)).to eq(
            :hide => [],
            :edit => %i(pxe_image_id pxe_server_id iso_image_id)
          )
        end
      end

      context "when iso is not supported" do
        let(:supports_iso) { false }

        it "returns the values to be edit and hidden" do
          expect(subject.determine_visibility(supports_iso, supports_pxe)).to eq(
            :hide => [:iso_image_id],
            :edit => %i(pxe_image_id pxe_server_id)
          )
        end
      end
    end

    context "when pxe is not supported" do
      let(:supports_pxe) { false }

      context "when iso is supported" do
        let(:supports_iso) { true }

        it "returns the values to be edit and hidden" do
          expect(subject.determine_visibility(supports_iso, supports_pxe)).to eq(
            :hide => %i(pxe_image_id pxe_server_id),
            :edit => [:iso_image_id]
          )
        end
      end

      context "when iso is not supported" do
        let(:supports_iso) { false }

        it "returns the values to be edit and hidden" do
          expect(subject.determine_visibility(supports_iso, supports_pxe)).to eq(
            :hide => %i(pxe_image_id pxe_server_id iso_image_id),
            :edit => []
          )
        end
      end
    end
  end
end
