require "spec_helper"
require "routing/shared_examples"

describe "routes for MiqProxyController" do
  let(:controller_name) { "miq_proxy" }

  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has policy protect routes"

  describe "#button" do
    it 'routes with POST' do
      expect(post("/miq_proxy/button")).to route_to("miq_proxy#button")
    end
  end

  describe "#change_tab" do
    it 'routes with GET' do
      expect(get("/miq_proxy/change_tab")).to route_to("miq_proxy#change_tab")
    end
    it 'routes with POST' do
      expect(post("/miq_proxy/change_tab")).to route_to("miq_proxy#change_tab")
    end
  end

  describe "#create" do
    it 'routes with POST' do
      expect(post("/miq_proxy/create")).to route_to("miq_proxy#create")
    end
  end

  describe "#credential_field_changed" do
    it 'routes with POST' do
      expect(post("/miq_proxy/credential_field_changed")).to route_to("miq_proxy#credential_field_changed")
    end
  end

  describe "#edit" do
    it 'routes with GET' do
      expect(get("miq_proxy/edit")).to route_to("miq_proxy#edit")
    end
  end

  describe "#fetch_zip" do
    it "routes with GET" do
      expect(get("/miq_proxy/fetch_zip")).to route_to("miq_proxy#fetch_zip")
    end
  end

  describe "#form_field_changed" do
    it 'routes with POST' do
      expect(post("/miq_proxy/form_field_changed")).to route_to("miq_proxy#form_field_changed")
    end
  end

  describe "#get_log" do
    it "routes with GET" do
      expect(get("miq_proxy/get_log")).to route_to("miq_proxy#get_log")
    end

    it "routes with POST" do
      expect(post("/miq_proxy/get_log")).to route_to("miq_proxy#get_log")
    end
  end

  describe "#index" do
    it 'routes with GET' do
      expect(get("miq_proxy/index")).to route_to("miq_proxy#index")
    end
    it 'routes with POST' do
      expect(post("miq_proxy/index")).to route_to("miq_proxy#index")
    end
  end

  describe "#install_007" do
    it "routes with GET" do
      expect(get("miq_proxy/install_007")).to route_to("miq_proxy#install_007")
    end

    it "routes with POST" do
      expect(post("/miq_proxy/install_007")).to route_to("miq_proxy#install_007")
    end
  end

  describe "#jobs" do
    it "routes with GET" do
      expect(get("miq_proxy/jobs")).to route_to("miq_proxy#jobs")
    end

    it "routes with POST" do
      expect(post("/miq_proxy/jobs")).to route_to("miq_proxy#jobs")
    end
  end

  describe "#log_viewer" do
    it 'routes with GET' do
      expect(get("miq_proxy/log_viewer")).to route_to("miq_proxy#log_viewer")
    end
  end

  describe "#new" do
    it 'routes with GET' do
      expect(get("miq_proxy/new")).to route_to("miq_proxy#new")
    end
  end

  describe "#show" do
    it 'routes with GET' do
      expect(get("miq_proxy/show")).to route_to("miq_proxy#show")
    end
  end

  describe "#show_list" do
    it "routes with GET" do
      expect(get("miq_proxy/show_list")).to route_to("miq_proxy#show_list")
    end

    it "routes with POST" do
      expect(post("/miq_proxy/show_list")).to route_to("miq_proxy#show_list")
    end
  end

  describe "#panel_control" do
    it 'routes with POST' do
      expect(post("/miq_proxy/panel_control")).to route_to("miq_proxy#panel_control")
    end
  end

  describe "#tasks_button" do
    it 'routes with POST' do
      expect(post("/miq_proxy/tasks_button")).to route_to("miq_proxy#tasks_button")
    end
  end

  describe "#tasks_change_options" do
    it 'routes with POST' do
      expect(post("/miq_proxy/tasks_change_options")).to route_to("miq_proxy#tasks_change_options")
    end
  end

  describe "#tasks_show_option" do
    it 'routes with GET' do
      expect(get("miq_proxy/tasks_show_option")).to route_to("miq_proxy#tasks_show_option")
    end
  end

  describe "#update" do
    it 'routes with POST' do
      expect(post("/miq_proxy/update")).to route_to("miq_proxy#update")
    end
  end
end
