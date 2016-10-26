require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration/Operations' \
                        '/Methods.class/__methods__/available_images.rb').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableImages do
  let(:root_hash) do
    { 'service_template' => MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template.id) }
  end
  let(:root_object) { Spec::Support::MiqAeMockObject.new(root_hash) }
  let(:ae_service) do
    Spec::Support::MiqAeMockService.new(root_object).tap do |service|
      current_object = Spec::Support::MiqAeMockObject.new
      current_object.parent = root_object
      service.object = current_object
    end
  end

  shared_examples_for "#having only default value" do
    let(:default_desc_blank) { "<none>" }

    it "provides only default value to the image list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to eq(nil => default_desc_blank)
      expect(ae_service["default_value"]).to be_nil
    end
  end

  shared_examples_for "#having the only image" do
    let(:img1) { FactoryGirl.create(:template_openstack, :uid_ems => 'uid1') }
    let(:ems) { FactoryGirl.create(:ems_openstack, :miq_templates => [img1]) }

    it "finds the only image and set it as the only item in the list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to include(
        img1.uid_ems => "unknown | #{img1.name}"
      )
      expect(ae_service["default_value"]).to eq(img1.uid_ems)
    end
  end

  shared_examples_for "#having all images" do
    let(:default_desc) { "<select>" }
    let(:hw1) { FactoryGirl.create(:hardware, :guest_os => 'windows') }
    let(:hw2) { FactoryGirl.create(:hardware, :guest_os => 'linux') }
    let(:img1) { FactoryGirl.create(:template_openstack, :uid_ems => 'uid1', :hardware => hw1) }
    let(:img2) { FactoryGirl.create(:template_openstack, :uid_ems => 'uid2', :hardware => hw2) }
    let(:ems) { FactoryGirl.create(:ems_openstack, :miq_templates => [img1, img2]) }

    it "finds all of the images and populates the list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to include(
        nil          => default_desc,
        img1.uid_ems => "windows | #{img1.name}",
        img2.uid_ems => "linux | #{img2.name}"
      )
      expect(ae_service["default_value"]).to be_nil
    end
  end

  context "workspace has no service template" do
    let(:root_hash) { {} }

    it_behaves_like "#having only default value"
  end

  context "workspace has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it_behaves_like "#having only default value"
  end

  context "workspace has orchestration service template" do
    context "with Orchestration Manager" do
      let(:service_template) do
        FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
      end

      context "with all images" do
        it_behaves_like "#having all images"
      end

      context "with one image" do
        it_behaves_like "#having the only image"
      end
    end

    context "without Orchestration Manager" do
      let(:service_template) do
        FactoryGirl.create(:service_template_orchestration)
      end

      it_behaves_like "#having only default value"
    end
  end

  context "workspace has orchestration service" do
    let(:root_hash) do
      { 'service_template' => MiqAeMethodService::MiqAeServiceService.find(service_template.id) }
    end

    context "with Orchestration Manager" do
      let(:service_template) do
        FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
      end

      context "with all images" do
        it_behaves_like "#having all images"
      end

      context "with one image" do
        it_behaves_like "#having the only image"
      end
    end

    context "without Orchestration Manager" do
      let(:service_template) { FactoryGirl.create(:service_orchestration) }

      it_behaves_like "#having only default value"
    end
  end
end
