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
        retirement_visibility_service,
        customize_fields_visibility_service,
        sysprep_custom_spec_visibility_service,
        request_type_visibility_service,
        pxe_iso_visibility_service,
        linked_clone_visibility_service
      )
    end

    let(:options) do
      {
        :addr_mode                       => addr_mode,
        :auto_placement_enabled          => auto_placement_enabled,
        :customize_fields_list           => customize_fields_list,
        :linked_clone                    => linked_clone,
        :number_of_vms                   => number_of_vms,
        :platform                        => platform,
        :provision_type                  => provision_type,
        :request_type                    => request_type,
        :retirement                      => retirement,
        :service_template_request        => service_template_request,
        :supports_customization_template => supports_customization_template,
        :supports_iso                    => supports_iso,
        :supports_pxe                    => supports_pxe,
        :sysprep_auto_logon              => sysprep_auto_logon,
        :sysprep_custom_spec             => sysprep_custom_spec,
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

    let(:customize_fields_visibility_service) { double("CustomizeFieldsVisibilityService") }
    let(:supports_customization_template) { "supports_customization_template" }
    let(:customize_fields_list) { "customize_fields_list" }

    let(:sysprep_custom_spec_visibility_service) { double("SysprepCustomSpecVisibilityService") }
    let(:sysprep_custom_spec) { "sysprep_custom_spec" }

    let(:request_type_visibility_service) { double("RequestTypeVisibilityService") }
    let(:request_type) { "request_type" }

    let(:pxe_iso_visibility_service) { double("PxeIsoVisibilityService") }

    let(:linked_clone_visibility_service) { double("LinkedCloneVisibilityService") }
    let(:provision_type) { "provision_type" }
    let(:linked_clone) { "linked_clone" }

    before do
      allow(service_template_fields_visibility_service)
        .to receive(:determine_visibility).with(service_template_request).and_return(
          :hide => [:service_template_request_hide]
        )

      allow(auto_placement_visibility_service)
        .to receive(:determine_visibility).with(auto_placement_enabled).and_return(
          :hide => [:auto_hide], :show => [:auto_show]
        )

      allow(number_of_vms_visibility_service)
        .to receive(:determine_visibility).with(number_of_vms, platform).and_return(
          :hide => [:number_hide], :show => [:number_show]
        )

      allow(network_visibility_service)
        .to receive(:determine_visibility).with(sysprep_enabled, supports_pxe, supports_iso, addr_mode).and_return(
          :hide => [:network_hide], :show => [:network_show]
        )

      allow(sysprep_auto_logon_visibility_service)
        .to receive(:determine_visibility).with(sysprep_auto_logon).and_return(
          :hide => [:sysprep_auto_logon_hide], :show => [:sysprep_auto_logon_show]
        )

      allow(retirement_visibility_service)
        .to receive(:determine_visibility).with(retirement).and_return(
          :hide => [:retirement_hide], :show => [:retirement_show]
        )

      allow(customize_fields_visibility_service)
        .to receive(:determine_visibility).with(
          platform, supports_customization_template, customize_fields_list
        ).and_return(
          :hide => [:customize_fields_hide, :number_hide], # Forces uniq
          :show => [:customize_fields_show, :number_show, :retirement_hide] # Forces uniq and removal of intersection
        )

      allow(sysprep_custom_spec_visibility_service)
        .to receive(:determine_visibility).with(sysprep_custom_spec).and_return(
          :hide => [:sysprep_custom_spec_hide],
          :show => [:sysprep_custom_spec_show]
        )

      allow(request_type_visibility_service)
        .to receive(:determine_visibility).with(request_type).and_return(:hide => [:request_type_hide])

      allow(pxe_iso_visibility_service)
        .to receive(:determine_visibility).with(supports_iso, supports_pxe).and_return(
          :hide => [:pxe_iso_hide],
          :show => [:pxe_iso_show]
        )

      allow(linked_clone_visibility_service)
        .to receive(:determine_visibility).with(provision_type, linked_clone).and_return(
          :hide => [:linked_clone_hide],
          :show => [:linked_clone_show]
        )
    end

    it "adds the values to the field names to hide and show without duplicates or intersections" do
      result = subject.determine_visibility(options)
      expect(result[:hide]).to match_array([
        :auto_hide,
        :customize_fields_hide,
        :linked_clone_hide,
        :network_hide,
        :number_hide,
        :pxe_iso_hide,
        :request_type_hide,
        :service_template_request_hide,
        :sysprep_auto_logon_hide,
        :sysprep_custom_spec_hide
      ])
      expect(result[:edit]).to match_array([
        :auto_show,
        :customize_fields_show,
        :linked_clone_show,
        :network_show,
        :number_show,
        :pxe_iso_show,
        :retirement_hide,
        :retirement_show,
        :sysprep_auto_logon_show,
        :sysprep_custom_spec_show
      ])
    end
  end

  describe "#set_hidden_fields" do
    let(:fields) { [field] }
    let(:field) { {:name => field_name, :display => :unchanged, :display_override => display_override} }
    let(:field_names_to_hide) { ["hide_me"] }

    context "when the field name is contained in the field names to hide" do
      let(:field_name) { "hide_me" }

      context "when the field has a display override" do
        let(:display_override) { :potato }

        it "sets the field's display property to :hide" do
          subject.set_hidden_fields(field_names_to_hide, fields)
          expect(field[:display]).to eq(:potato)
        end
      end

      context "when the field display override is blank" do
        let(:display_override) { "" }

        it "sets the field's display property to :hide" do
          subject.set_hidden_fields(field_names_to_hide, fields)
          expect(field[:display]).to eq(:hide)
        end
      end
    end

    context "when the field name is not contained in the field names to hide" do
      let(:field_name) { "test" }
      let(:display_override) { "" }

      it "does not change the field's display property" do
        subject.set_hidden_fields(field_names_to_hide, fields)
        expect(field[:display]).to eq(:unchanged)
      end
    end
  end

  describe "#set_shown_fields" do
    let(:fields) { [field] }
    let(:field) { {:name => field_name, :display => :unchanged, :display_override => display_override} }
    let(:field_names_to_show) { ["show_me"] }

    context "when the field name is contained in the field names to hide" do
      let(:field_name) { "show_me" }

      context "when the field has a display override" do
        let(:display_override) { :potato }

        it "sets the field's display property to the override" do
          subject.set_shown_fields(field_names_to_show, fields)
          expect(field[:display]).to eq(:potato)
        end
      end

      context "when the field display override is blank" do
        let(:display_override) { "" }

        it "sets the field's display property to :edit" do
          subject.set_shown_fields(field_names_to_show, fields)
          expect(field[:display]).to eq(:edit)
        end
      end
    end

    context "when the field name is not contained in the field names to show" do
      let(:field_name) { "test" }
      let(:display_override) { nil }

      it "does not change the field's display property" do
        subject.set_shown_fields(field_names_to_show, fields)
        expect(field[:display]).to eq(:unchanged)
      end
    end
  end
end
