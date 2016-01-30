require "routing/shared_examples"

describe "routes for MiqTemplateController" do
  let(:controller_name) { "miq_template" }

  %w(
    edit
    show
    ownership
  ).each do |task|
    describe "##{task}" do
      it 'routes with GET' do
        expect(get("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end

  %w(
    edit
    edit_vm
    form_field_changed
    show
  ).each do |task|
    describe "##{task}" do
      it 'routes with POST' do
        expect(post("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end
end
