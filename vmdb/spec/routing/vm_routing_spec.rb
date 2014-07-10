require "spec_helper"
require "routing/shared_examples"

describe VmOrTemplateController do
  let(:controller_name) { "vm" }

  %w(
    edit
    ownership
    policy_sim
    reconfigure
    retire
    right_size
    show
  ).each do |path|
    describe "##{path}" do
      it "routes with GET" do
        expect(get("/#{controller_name}/#{path}")).to route_to("#{controller_name}##{path}")
      end
    end
  end

  %w(
    edit_vm
    form_field_changed
    ownership
    ownership_field_changed
    ownership_update
    policy_sim
    policy_sim_add
    policy_sim_remove
    pre_prov
    pre_prov_continue
    provision
    reconfigure
    reconfigure_field_changed
    reconfigure_update
    retire
    retire_date_changed
    right_size
  ).each do |path|
    describe "##{path}" do
      it "routes with POST" do
        expect(post("/#{controller_name}/#{path}")).to route_to("#{controller_name}##{path}")
      end
    end
  end
end
