require "spec_helper"
require "routing/shared_examples"

describe VmOrTemplateController do
  let(:controller_name) { "vm_or_template" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has policy protect routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has timeline routes"
  it_behaves_like "A controller that has utilization routes"

  describe "#explorer" do
    it "routes with GET" do
      expect(get("/vm_or_template/explorer")).to route_to("vm_or_template#explorer")
    end

    it "rotues with POST" do
      expect(post("/vm_or_template/explorer")).to route_to("vm_or_template#explorer")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/vm_or_template/show")).to route_to("vm_or_template#show")
    end

    it "rotues with POST" do
      expect(post("/vm_or_template/show")).to route_to("vm_or_template#show")
    end
  end

  %w(
    drift_to_csv
    drift_to_pdf
    drift_to_txt
    vm_show
  ).each do |path|
    describe "##{path}" do
      it "routes with GET" do
        expect(get("/vm_or_template/#{path}")).to route_to("vm_or_template##{path}")
      end
    end
  end

  %w(
    accordion_select
    advanced_settings
    button
    dialog_field_changed
    dialog_form_button_pressed
    drift_all
    drift_differences
    drift_history
    drift_mode
    drift_same
    edit_vm
    event_logs
    evm_relationship_field_changed
    evm_relationship_update
    filesystem_drivers
    filesystems
    form_field_changed
    groups
    guest_applications
    kernel_drivers
    linux_initprocesses
    ontap_file_shares
    ontap_logical_disks
    ontap_storage_systems
    ownership_field_changed
    ownership_update
    patches
    perf_chart_chooser
    policies
    policy_options
    policy_show_options
    policy_sim
    policy_sim_add
    policy_sim_remove
    pre_prov
    processes
    prov_edit
    prov_field_changed
    reconfigure_field_changed
    reconfigure_update
    registry_items
    reload
    retire
    retire_date_changed
    scan_histories
    sections_field_changed
    snap_pressed
    snap_vm
    sort_ds_grid
    sort_host_grid
    sort_iso_img_grid
    squash_toggle
    tree_select
    users
    vm_pre_prov
    vmrc_console
    vnc_console
    wait_for_task
    win32_services
    x_button
    x_history
    x_search_by_name
    x_show
  ).each do |path|
    describe "##{path}" do
      it "routes with POST" do
        expect(post("/vm_or_template/#{path}")).to route_to("vm_or_template##{path}")
      end
    end
  end
end
