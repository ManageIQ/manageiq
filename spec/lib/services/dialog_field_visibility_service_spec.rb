describe DialogFieldVisibilityService do
  let(:subject) { described_class.new }

  context "accessors" do
    it "defines an auto_placement_visibility_service accessor" do
      expect(subject).to respond_to(:auto_placement_visibility_service)
      expect(subject).to respond_to(:auto_placement_visibility_service=)
    end

    it "defines an number_of_vms_visibility_service accessor" do
      expect(subject).to respond_to(:number_of_vms_visibility_service)
      expect(subject).to respond_to(:number_of_vms_visibility_service=)
    end

    it "defines an service_template_fields_visibility_service accessor" do
      expect(subject).to respond_to(:service_template_fields_visibility_service)
      expect(subject).to respond_to(:service_template_fields_visibility_service=)
    end

    it "defines an network_visibility_service accessor" do
      expect(subject).to respond_to(:network_visibility_service)
      expect(subject).to respond_to(:network_visibility_service=)
    end

    it "defines an sysprep_auto_logon_visibility_service accessor" do
      expect(subject).to respond_to(:sysprep_auto_logon_visibility_service)
      expect(subject).to respond_to(:sysprep_auto_logon_visibility_service=)
    end

    it "defines an retirement_visibility_service accessor" do
      expect(subject).to respond_to(:retirement_visibility_service)
      expect(subject).to respond_to(:retirement_visibility_service=)
    end

    it "defines an customize_fields_visibility_service accessor" do
      expect(subject).to respond_to(:customize_fields_visibility_service)
      expect(subject).to respond_to(:customize_fields_visibility_service=)
    end

    it "defines an sysprep_custom_spec_visibility_service accessor" do
      expect(subject).to respond_to(:sysprep_custom_spec_visibility_service)
      expect(subject).to respond_to(:sysprep_custom_spec_visibility_service=)
    end

    it "defines an request_type_visibility_service accessor" do
      expect(subject).to respond_to(:request_type_visibility_service)
      expect(subject).to respond_to(:request_type_visibility_service=)
    end

    it "defines an pxe_iso_visibility_service accessor" do
      expect(subject).to respond_to(:pxe_iso_visibility_service)
      expect(subject).to respond_to(:pxe_iso_visibility_service=)
    end

    it "defines an linked_clone_visibility_service accessor" do
      expect(subject).to respond_to(:linked_clone_visibility_service)
      expect(subject).to respond_to(:linked_clone_visibility_service=)
    end
  end

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
        :snapshot_count                  => snapshot_count,
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
    let(:snapshot_count) { "snapshot_count" }

    before do
      allow(service_template_fields_visibility_service)
        .to receive(:determine_visibility).with(service_template_request).and_return(
          :hide => [:service_template_request_hide]
        )

      allow(auto_placement_visibility_service)
        .to receive(:determine_visibility).with(auto_placement_enabled).and_return(
          :hide => [:auto_hide], :edit => [:auto_edit]
        )

      allow(number_of_vms_visibility_service)
        .to receive(:determine_visibility).with(number_of_vms, platform).and_return(
          :hide => [:number_hide], :edit => [:number_edit]
        )

      allow(network_visibility_service)
        .to receive(:determine_visibility).with(sysprep_enabled, supports_pxe, supports_iso, addr_mode).and_return(
          :hide => [:network_hide], :edit => [:network_edit]
        )

      allow(sysprep_auto_logon_visibility_service)
        .to receive(:determine_visibility).with(sysprep_auto_logon).and_return(
          :hide => [:sysprep_auto_logon_hide], :edit => [:sysprep_auto_logon_edit]
        )

      allow(retirement_visibility_service)
        .to receive(:determine_visibility).with(retirement).and_return(
          :hide => [:retirement_hide], :edit => [:retirement_edit]
        )

      allow(customize_fields_visibility_service)
        .to receive(:determine_visibility).with(
          platform, supports_customization_template, customize_fields_list
        ).and_return(
          :hide => %i(customize_fields_hide number_hide), # Forces uniq
          :edit => %i(customize_fields_edit number_edit retirement_hide) # Forces uniq and removal of intersection
        )

      allow(sysprep_custom_spec_visibility_service)
        .to receive(:determine_visibility).with(sysprep_custom_spec).and_return(
          :hide => [:sysprep_custom_spec_hide],
          :edit => [:sysprep_custom_spec_edit]
        )

      allow(request_type_visibility_service)
        .to receive(:determine_visibility).with(request_type).and_return(:hide => [:request_type_hide])

      allow(pxe_iso_visibility_service)
        .to receive(:determine_visibility).with(supports_iso, supports_pxe).and_return(
          :hide => [:pxe_iso_hide],
          :edit => [:pxe_iso_edit]
        )

      allow(linked_clone_visibility_service)
        .to receive(:determine_visibility).with(provision_type, linked_clone, snapshot_count).and_return(
          :hide => [:linked_clone_hide],
          :edit => [:linked_clone_edit],
          :show => [:linked_clone_show]
        )
    end

    it "adds the values to the field names to hide, edit, and show without duplicates or intersections" do
      result = subject.determine_visibility(options)
      expect(result[:hide]).to match_array(%i(
                                             auto_hide
                                             customize_fields_hide
                                             linked_clone_hide
                                             network_hide
                                             number_hide
                                             pxe_iso_hide
                                             request_type_hide
                                             service_template_request_hide
                                             sysprep_auto_logon_hide
                                             sysprep_custom_spec_hide
                                           ))
      expect(result[:edit]).to match_array(%i(
                                             auto_edit
                                             customize_fields_edit
                                             linked_clone_edit
                                             network_edit
                                             number_edit
                                             pxe_iso_edit
                                             retirement_hide
                                             retirement_edit
                                             sysprep_auto_logon_edit
                                             sysprep_custom_spec_edit
                                           ))
      expect(result[:show]).to match_array([:linked_clone_show])
    end
  end

  describe "#set_visibility_for_field" do
    let(:field) { {:display_override => display_override} }
    let(:visibility_hash) { {:edit => "edit_me", :hide => "hide_me", :show => "show_me"} }

    before do
      subject.set_visibility_for_field(visibility_hash, field_name, field)
    end

    shared_examples_for "#set_visibility_for_field with a display override" do
      context "when the field has a display override" do
        let(:display_override) { :potato }

        it "sets the display value to the override" do
          expect(field[:display]).to eq(:potato)
        end
      end
    end

    context "when the field name is contained in the field names to edit" do
      let(:field_name) { "edit_me" }

      it_behaves_like "#set_visibility_for_field with a display override"

      context "when the field display override is blank" do
        let(:display_override) { "" }

        it "sets the display value to edit" do
          expect(field[:display]).to eq(:edit)
        end
      end
    end

    context "when the field name is contained in the field names to hide" do
      let(:field_name) { "hide_me" }

      it_behaves_like "#set_visibility_for_field with a display override"

      context "when the field display override is blank" do
        let(:display_override) { "" }

        it "sets the display value to hide" do
          expect(field[:display]).to eq(:hide)
        end
      end
    end

    context "when the field name is contained in the field names to show" do
      let(:field_name) { "show_me" }

      it_behaves_like "#set_visibility_for_field with a display override"

      context "when the field display override is blank" do
        let(:display_override) { "" }

        it "sets the display value to show" do
          expect(field[:display]).to eq(:show)
        end
      end
    end

    context "when the field name is not contained in either the field names to edit or hide or show" do
      let(:field_name) { "potato" }

      it_behaves_like "#set_visibility_for_field with a display override"

      context "when the field display override is blank" do
        let(:display_override) { "" }

        context "when the field does not have a display value" do
          let(:display) { nil }

          it "sets the display value to edit" do
            expect(field[:display]).to eq(:edit)
          end
        end

        context "when the field does have a display value" do
          let(:field) { {:display_override => display_override, :display => :hide} }

          it "uses the given display value" do
            expect(field[:display]).to eq(:hide)
          end
        end
      end
    end
  end
end
