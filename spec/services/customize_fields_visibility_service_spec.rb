describe CustomizeFieldsVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when the customization template is supported" do
      let(:supports_customization_template) { true }
      let(:platform) { "potato" }
      let(:customize_fields_list) { "potato" }

      it "returns a list of pxe customization fields to show" do
        expect(subject.determine_visibility(platform, supports_customization_template, customize_fields_list)).to eq(
          :hide => [],
          :show => [
            :addr_mode,
            :customization_template_id,
            :customization_template_script,
            :dns_servers,
            :dns_suffixes,
            :gateway,
            :hostname,
            :ip_addr,
            :root_password,
            :subnet_mask
          ]
        )
      end
    end

    context "when the customization template is not supported" do
      let(:supports_customization_template) { false }

      context "when the customize_fields_list contains only items from exclude list" do
        let(:customize_fields_list) do
          [
            :sysprep_spec_override,
            :sysprep_custom_spec,
            :sysprep_enabled,
            :sysprep_upload_file,
            :sysprep_upload_text,
            :linux_host_name,
            :sysprep_computer_name,
            :ip_addr,
            :subnet_mask,
            :gateway,
            :dns_servers,
            :dns_suffixes
          ]
        end
        let(:platform) { "linux" }

        it "returns an empty hide/show hash" do
          expect(subject.determine_visibility(platform, supports_customization_template, customize_fields_list)).to eq(
            :hide => [], :show => []
          )
        end
      end

      context "when the customize_fields_list contains linux_domain_name" do
        let(:customize_fields_list) { [:linux_domain_name, :potato] }

        context "when the platform is linux" do
          let(:platform) { "linux" }

          it "returns the correct list of things to show/hide" do
            expect(subject.determine_visibility(
              platform,
              supports_customization_template,
              customize_fields_list)).to eq(
                :hide => [:potato], :show => [:linux_domain_name]
              )
          end
        end

        context "when the platform is not linux" do
          let(:platform) { "potato" }

          it "returns an empty hide/show hash" do
            expect(subject.determine_visibility(
              platform,
              supports_customization_template,
              customize_fields_list)).to eq(
                :hide => [], :show => []
              )
          end
        end
      end
    end
  end
end
