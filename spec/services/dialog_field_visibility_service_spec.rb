describe DialogFieldVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    let(:subject) do
      described_class.new(
        auto_placement_visibility_service,
        number_of_vms_visibility_service,
        service_template_fields_visibility_service,
        network_visibility_service,
        sysprep_auto_logon_visibility_service,
        retirement_visibility_service
      )
    end

    let(:options) do
      {
        :addr_mode                       => addr_mode,
        :auto_placement_enabled          => auto_placement_enabled,
        :number_of_vms                   => number_of_vms,
        :platform                        => platform,
        :retirement                      => retirement,
        :service_template_request        => service_template_request,
        :supports_iso                    => supports_iso,
        :supports_pxe                    => supports_pxe,
        :sysprep_auto_logon              => sysprep_auto_logon,
        :sysprep_enabled                 => sysprep_enabled
      }
    end

    let(:service_template_fields_visibility_service) { double("ServiceTemplateFieldsVisibilityService") }
    let(:service_template_request) { "service_template_request" }

    let(:auto_placement_visibility_service) { double("AutoPlacementVisibilityService") }
    let(:auto_placement_enabled) { "auto_placement_enabled" }

    let(:number_of_vms_visibility_service) { double("NumberOfVmsVisibilityService") }
    let(:number_of_vms) { "number_of_vms" }
    let(:platform) { "platform" }

    let(:network_visibility_service) { double("NetworkVisibilityService") }
    let(:sysprep_enabled) { "sysprep_enabled" }
    let(:supports_pxe) { "supports_pxe" }
    let(:supports_iso) { "supports_iso" }
    let(:addr_mode) { "addr_mode" }

    let(:sysprep_auto_logon_visibility_service) { double("SysprepAutoLogonVisibilityService") }
    let(:sysprep_auto_logon) { "sysprep_auto_logon" }

    let(:retirement_visibility_service) { double("RetirementVisibilityService") }
    let(:retirement) { "retirement" }

    before do
      allow(service_template_fields_visibility_service).
        to receive(:determine_visibility).with(service_template_request).and_return(
          {:hide => [:service_template_request_hide]}
        )
      allow(auto_placement_visibility_service).
        to receive(:determine_visibility).with(auto_placement_enabled).and_return(
          {:hide => [:auto_hide], :show => [:auto_show]}
        )
      allow(number_of_vms_visibility_service).
        to receive(:determine_visibility).with(number_of_vms, platform).and_return(
          {:hide => [:number_hide], :show => [:number_show]}
        )
      allow(network_visibility_service).
        to receive(:determine_visibility).with(sysprep_enabled, supports_pxe, supports_iso, addr_mode).and_return(
          {:hide => [:network_hide], :show => [:network_show]}
        )
      allow(sysprep_auto_logon_visibility_service).
        to receive(:determine_visibility).with(sysprep_auto_logon).and_return(
          {:hide => [:sysprep_auto_logon_hide], :show => [:sysprep_auto_logon_show]}
        )
      allow(retirement_visibility_service).
        to receive(:determine_visibility).with(retirement).and_return(
          {:hide => [:retirement_hide], :show => [:retirement_show]}
        )
    end

    it "adds the values to the field names to hide and show without duplicates or intersections" do
      expect(subject.determine_visibility(options)).to eq({
        :hide => [
          :service_template_request_hide,
          :auto_hide,
          :number_hide
        ],
        :edit => [
          :auto_show,
          :number_show
        ]
      })
    end
  end
end
