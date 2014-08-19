require "spec_helper"

describe MiqAeToolsController do
  describe "#resolve" do
    it "routes with GET" do
      expect(get("/miq_ae_tools/resolve")).to route_to("miq_ae_tools#resolve")
    end

    it "routes with POST" do
      expect(post("/miq_ae_tools/resolve")).to route_to("miq_ae_tools#resolve")
    end
  end

  %w(
    automate_json
    export_datastore
    fetch_log
    import_export
    log
    review_import
  ).each do |action|
    describe "##{action}" do
      it "routes with GET" do
        expect(get("/miq_ae_tools/#{action}")).to route_to("miq_ae_tools##{action}")
      end
    end
  end

  %w(
    button
    cancel_import
    form_field_changed
    import_automate_datastore
    reset_datastore
    resolve
    upload
    upload_import_file
    wait_for_task
  ).each do |action|
    describe "##{action}" do
      it "routes with POST" do
        expect(post("/miq_ae_tools/#{action}")).to route_to("miq_ae_tools##{action}")
      end
    end
  end
end
