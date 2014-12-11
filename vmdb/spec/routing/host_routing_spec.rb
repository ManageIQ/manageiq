require "spec_helper"
require "routing/shared_examples"

describe "routes for HostController" do
  let(:controller_name) { "host" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has timeline routes"
  it_behaves_like "A controller that has CRUD routes"
  it_behaves_like "A controller that has discovery routes"

  describe "#advanced_settings" do
    it "routes with GET" do
      expect(get("/host/advanced_settings")).to route_to("host#advanced_settings")
    end

    it "routes with POST" do
      expect(post("/host/advanced_settings")).to route_to("host#advanced_settings")
    end

  end

  describe "#button" do
    it "routes with POST" do
      expect(post("/host/button")).to route_to("host#button")
    end
  end

  describe "#dialog_field_changed" do
    it "routes with POST" do
      expect(post("/host/dialog_field_changed")).to route_to("host#dialog_field_changed")
    end
  end

  describe "#dialog_form_button_pressed" do
    it "routes with POST" do
      expect(post("/host/dialog_form_button_pressed")).to route_to("host#dialog_form_button_pressed")
    end
  end

  describe "#dialog_load" do
    it "routes with GET" do
      expect(get("/host/dialog_load")).to route_to("host#dialog_load")
    end
  end

  describe "#drift" do
    it "routes with GET" do
      expect(get("/host/drift")).to route_to("host#drift")
    end
  end

  describe "#drift_all" do
    it "routes with POST" do
      expect(post("/host/drift_all")).to route_to("host#drift_all")
    end
  end

  describe "#drift_compress" do
    it "routes with POST" do
      expect(post("/host/drift_compress")).to route_to("host#drift_compress")
    end
  end

  describe "#drift_differences" do
    it "routes with POST" do
      expect(post("/host/drift_differences")).to route_to("host#drift_differences")
    end
  end

  describe "#drift_history" do
    it "routes with GET" do
      expect(get("/host/drift_history")).to route_to("host#drift_history")
    end
  end

  describe "#drift_mode" do
    it "routes with POST" do
      expect(post("/host/drift_mode")).to route_to("host#drift_mode")
    end
  end

  describe "#drift_same" do
    it "routes with POST" do
      expect(post("/host/drift_same")).to route_to("host#drift_same")
    end
  end

  describe "drift_to_csv" do
    it "routes with GET" do
      expect(get("/host/drift_to_csv")).to route_to("host#drift_to_csv")
    end
  end

  describe "drift_to_pdf" do
    it "routes with GET" do
      expect(get("/host/drift_to_pdf")).to route_to("host#drift_to_pdf")
    end
  end

  describe "#drift_to_txt" do
    it "routes with GET" do
      expect(get("/host/drift_to_txt")).to route_to("host#drift_to_txt")
    end
  end

  describe "#dynamic_list_refresh" do
    it "routes with POST" do
      expect(post("/host/dynamic_list_refresh")).to route_to("host#dynamic_list_refresh")
    end
  end

  describe "#dynamic_radio_button_refresh" do
    it "routes with POST" do
      expect(post("/host/dynamic_radio_button_refresh")).to route_to("host#dynamic_radio_button_refresh")
    end
  end

  describe "#filesystems" do
    it "routes with GET" do
      expect(get("/host/filesystems")).to route_to("host#filesystems")
    end

    it "routes with POST" do
      expect(post("/host/filesystems")).to route_to("host#filesystems")
    end

  end

  describe "#firewall_rules" do
    it "routes with GET" do
      expect(get("/host/firewall_rules")).to route_to("host#firewall_rules")
    end

    it "routes with POST" do
      expect(post("/host/firewall_rules")).to route_to("host#firewall_rules")
    end
  end

  describe "#firewallrules" do
    it "routes with POST" do
      expect(post("/host/firewallrules")).to route_to("host#firewallrules")
    end
  end

  describe "#form_field_changed" do
    it "routes with POST" do
      expect(post("/host/form_field_changed")).to route_to("host#form_field_changed")
    end
  end

  describe "#groups" do
    it "routes with GET" do
      expect(get("/host/groups")).to route_to("host#groups")
    end

    it "routes with POST" do
      expect(post("/host/groups")).to route_to("host#groups")
    end
  end

  describe "#guest_applications" do
    it "routes with GET" do
      expect(get("/host/guest_applications")).to route_to("host#guest_applications")
    end

    it "routes with POST" do
      expect(post("/host/guest_applications")).to route_to("host#guest_applications")
    end
  end

  describe "#host_services" do
    it "routes with GET" do
      expect(get("/host/host_services")).to route_to("host#host_services")
    end

    it "routes with POST" do
      expect(post("/host/host_services")).to route_to("host#host_services")
    end
  end

  describe "#list" do
    it "routes with GET" do
      expect(get("/host/list")).to route_to("host#list")
    end
  end

  describe "#listnav_search_selected" do
    it "routes with POST" do
      expect(post("/host/listnav_search_selected")).to route_to("host#listnav_search_selected")
    end
  end

  describe "#panel_control" do
    it "routes with POST" do
      expect(post("/host/panel_control")).to route_to("host#panel_control")
    end
  end

  describe "#patches" do
    it "routes with GET" do
      expect(get("/host/patches")).to route_to("host#patches")
    end

    it "routes with POST" do
      expect(post("/host/patches")).to route_to("host#patches")
    end
  end

  describe "#perf_chart_chooser" do
    it "routes with POST" do
      expect(post("/host/perf_chart_chooser")).to route_to("host#perf_chart_chooser")
    end
  end

  describe "#perf_top_chart" do
    it "routes with GET" do
      expect(get("/#{controller_name}/perf_top_chart")).to route_to("#{controller_name}#perf_top_chart")
    end
  end

  describe "#perf_top_chart" do
    it "routes with POST" do
      expect(post("/#{controller_name}/perf_top_chart")).to route_to("#{controller_name}#perf_top_chart")
    end
  end

  describe "#save_default_search" do
    it "routes with POST" do
      expect(post("/host/save_default_search")).to route_to("host#save_default_search")
    end
  end

  describe "#sections_field_changed" do
    it "routes with POST" do
      expect(post("/host/sections_field_changed")).to route_to("host#sections_field_changed")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/host/show")).to route_to("host#show")
    end

    it "routes with POST" do
      expect(post("/host/show")).to route_to("host#show")
    end
  end

  describe "#show_association" do
    it "routes with GET" do
      expect(get("/host/show_association")).to route_to("host#show_association")
    end
  end

  describe "#show_details" do
    it "routes with GET" do
      expect(get("/host/show_details")).to route_to("host#show_details")
    end
  end

  describe "#start" do
    it "routes with GET" do
      expect(get("/host/start")).to route_to("host#start")
    end
  end

  describe "#squash_toggle" do
    it "routes with POST" do
      expect(post("/host/squash_toggle")).to route_to("host#squash_toggle")
    end
  end

  describe "#toggle_policy_profile" do
    it "routes with POST" do
      expect(post("/host/toggle_policy_profile")).to route_to("host#toggle_policy_profile")
    end
  end

  describe "#users" do
    it "routes with GET" do
      expect(get("/host/users")).to route_to("host#users")
    end

    it "routes with POST" do
      expect(post("/host/users")).to route_to("host#users")
    end
  end
end
