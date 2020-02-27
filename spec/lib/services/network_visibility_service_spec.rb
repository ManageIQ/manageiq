describe NetworkVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    let(:supports_pxe) { nil }
    let(:supports_iso) { nil }
    let(:addr_mode) { nil }

    shared_examples_for "NetworkVisibilityService#determine_visibility that shows everything" do
      it "adds the network values to the edit values" do
        expect(subject.determine_visibility(sysprep_enabled, supports_pxe, supports_iso, addr_mode)).to eq(
          :hide => [],
          :edit => %i(addr_mode dns_suffixes dns_servers ip_addr subnet_mask gateway)
        )
      end
    end

    shared_examples_for "NetworkVisibilityService#determine_visibility sysprep_enabled is 'fields' or 'file'" do
      context "when addr_mode is static" do
        let(:addr_mode) { "static" }

        it_behaves_like "NetworkVisibilityService#determine_visibility that shows everything"
      end

      context "when addr_mode is not static" do
        let(:addr_mode) { "not static" }

        context "when supports_pxe is true" do
          let(:supports_pxe) { true }

          it_behaves_like "NetworkVisibilityService#determine_visibility that shows everything"
        end

        context "when supports_pxe is false" do
          let(:supports_pxe) { false }

          context "when supports_iso is true" do
            let(:supports_iso) { true }

            it_behaves_like "NetworkVisibilityService#determine_visibility that shows everything"
          end

          context "when supports_iso is false" do
            let(:supports_iso) { false }

            it "adds the correct values to the edit and hide values" do
              expect(subject.determine_visibility(sysprep_enabled, supports_pxe, supports_iso, addr_mode)).to eq(
                :hide => %i(ip_addr subnet_mask gateway),
                :edit => %i(addr_mode dns_suffixes dns_servers)
              )
            end
          end
        end
      end
    end

    context "when sysprep_enabled is 'fields'" do
      let(:sysprep_enabled) { "fields" }

      it_behaves_like "NetworkVisibilityService#determine_visibility sysprep_enabled is 'fields' or 'file'"
    end

    context "when sysprep_enabled is 'file'" do
      let(:sysprep_enabled) { "file" }

      it_behaves_like "NetworkVisibilityService#determine_visibility sysprep_enabled is 'fields' or 'file'"
    end

    context "when sysprep_enabled is something else" do
      let(:sysprep_enabled) { "potato" }

      context "when supports_pxe is true" do
        let(:supports_pxe) { true }

        context "when addr_mode is static" do
          let(:addr_mode) { "static" }

          it_behaves_like "NetworkVisibilityService#determine_visibility that shows everything"
        end

        context "when addr_mode is not static" do
          let(:addr_mode) { "not static" }

          context "when supports_iso is true" do
            let(:supports_iso) { true }

            it_behaves_like "NetworkVisibilityService#determine_visibility that shows everything"
          end

          context "when supports_iso is false" do
            let(:supports_iso) { false }

            it_behaves_like "NetworkVisibilityService#determine_visibility that shows everything"
          end
        end
      end

      context "when supports_pxe is false" do
        let(:supports_pxe) { false }

        context "when supports_iso is true" do
          let(:supports_iso) { true }

          context "when addr_mode is static" do
            let(:addr_mode) { "static" }

            it_behaves_like "NetworkVisibilityService#determine_visibility that shows everything"
          end

          context "when addr_mode is not static" do
            let(:addr_mode) { "not static" }

            it_behaves_like "NetworkVisibilityService#determine_visibility that shows everything"
          end
        end

        context "when supports_iso is false" do
          let(:supports_iso) { false }

          it "adds the correct values to the hide values" do
            expect(subject.determine_visibility(sysprep_enabled, supports_pxe, supports_iso, addr_mode)).to eq(
              :hide => %i(addr_mode ip_addr subnet_mask gateway dns_servers dns_suffixes),
              :edit => []
            )
          end
        end
      end
    end
  end
end
