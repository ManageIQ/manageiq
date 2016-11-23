describe "Quota Validation" do
  include Spec::Support::QuotaHelper
  include Spec::Support::ServiceTemplateHelper

  def run_automate_method(attrs)
    MiqAeEngine.instantiate("/ManageIQ/system/request/Call_Instance?namespace=System/CommonMethods&" \
                            "class=QuotaMethods&instance=requested&#{attrs.join('&')}", @user)
  end

  def vm_attrs
    ["MiqRequest::miq_request=#{@miq_provision_request.id}"]
  end

  def service_attrs
    ["MiqRequest::miq_request=#{@service_request.id}&" \
     "vmdb_object_type=service_template_provision_request"]
  end

  def check_results(requested_hash, storage, cpu, vms, memory)
    expect(requested_hash[:storage]).to eq(storage)
    expect(requested_hash[:cpu]).to eq(cpu)
    expect(requested_hash[:vms]).to eq(vms)
    expect(requested_hash[:memory]).to eq(memory)
  end

  context "Service provisioning quota" do
    it "generic calculate_requested" do
      setup_model("generic")
      build_generic_service_item
      expect { run_automate_method(service_attrs) }.not_to raise_exception
    end

    it "generic ansible tower calculate_requested" do
      setup_model("generic")
      build_generic_ansible_tower_service_item
      expect { run_automate_method(service_attrs) }.not_to raise_exception
    end

    it "vmware service item calculate_requested" do
      setup_model("vmware")
      build_small_environment
      build_vmware_service_item
      ws = run_automate_method(service_attrs)
      check_results(ws.root['quota_requested'], 512.megabytes, 4, 1, 1.gigabytes)
    end
  end

  context "Service Bundle provisioning quota" do
    it "Bundle of 2, google and vmware" do
      create_service_bundle([google_template, vmware_template])
      expect { run_automate_method(service_attrs) }.not_to raise_exception
    end

    it "Bundle of 2, google and generic" do
      create_service_bundle([google_template, generic_template])
      expect { run_automate_method(service_attrs) }.not_to raise_exception
    end
  end

  context "VM provisioning quota" do
    it "vmware calculate_requested" do
      setup_model("vmware")
      ws = run_automate_method(vm_attrs)
      check_results(ws.root['quota_requested'], 512.megabytes, 4, 1, 1.gigabytes)
    end

    it "google calculate_requested" do
      setup_model("google")
      ws = run_automate_method(vm_attrs)
      check_results(ws.root['quota_requested'], 10.gigabytes, 4, 1, 1024)
    end
  end
end
