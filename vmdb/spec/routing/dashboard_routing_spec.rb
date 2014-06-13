require 'spec_helper'

describe 'routes for DashboardController' do

  describe "#change_tab" do
    it "routes with GET" do
      expect(get("/dashboard/change_tab")).to route_to("dashboard#change_tab")
    end
  end

  describe '#index' do
    it 'routes with GET' do
      expect(get('/dashboard')).to route_to('dashboard#index')
    end
  end

  describe "#login" do
    it "routes with GET" do
      expect(get("/dashboard/login")).to route_to("dashboard#login")
    end
  end

  describe "#logout" do
    it "routes with GET" do
      expect(get("/dashboard/logout")).to route_to("dashboard#logout")
    end
  end

  describe "#maintab" do
    it "routes with GET" do
      expect(get("/dashboard/maintab")).to route_to("dashboard#maintab")
    end
  end

  describe "#render_csv" do
    it "routes with GET" do
      expect(get("/dashboard/render_chart")).to route_to("dashboard#render_chart")
    end
  end

  describe "#render_csv" do
    it "routes with GET" do
      expect(get("/dashboard/render_csv")).to route_to("dashboard#render_csv")
    end
  end

  describe "#render_pdf" do
    it "routes with GET" do
      expect(get("/dashboard/render_pdf")).to route_to("dashboard#render_pdf")
    end
  end

  describe "#render_txt" do
    it "routes with GET" do
      expect(get("/dashboard/render_txt")).to route_to("dashboard#render_txt")
    end
  end

  describe "#report_only" do
    it "routes with GET" do
      expect(get("/dashboard/report_only")).to route_to("dashboard#report_only")
    end
  end

  describe "#report_only" do
    it "routes with GET" do
      expect(get("/dashboard/report_only")).to route_to("dashboard#report_only")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/dashboard/show")).to route_to("dashboard#show")
    end
  end

  describe "#timeline" do
    it "routes with GET" do
      expect(get("/dashboard/timeline")).to route_to("dashboard#timeline")
    end
  end

  describe "#widget_to_pdf" do
    it "routes with GET" do
      expect(get("/dashboard/widget_to_pdf")).to route_to("dashboard#widget_to_pdf")
    end
  end

  describe "#authenticate" do
    it "routes with POST" do
      expect(post("/dashboard/authenticate")).to route_to("dashboard#authenticate")
    end
  end

  describe "#change_group" do
    it "routes with POST" do
      expect(post("/dashboard/change_group")).to route_to("dashboard#change_group")
    end
  end

  describe "#csp_report" do
    it "routes with POST" do
      expect(post("/dashboard/csp_report")).to route_to("dashboard#csp_report")
    end
  end

  describe "#getTLdata" do
    it "routes with POST" do
      expect(post("/dashboard/getTLdata")).to route_to("dashboard#getTLdata")
    end
  end

  describe "#login_retry" do
    it "routes with POST" do
      expect(post("/dashboard/login_retry")).to route_to("dashboard#login_retry")
    end
  end

  describe "#panel_control" do
    it "routes with POST" do
      expect(post("/dashboard/panel_control")).to route_to("dashboard#panel_control")
    end
  end

  describe "#reset_widgets" do
    it "routes with POST" do
      expect(post("/dashboard/reset_widgets")).to route_to("dashboard#reset_widgets")
    end
  end

  describe "#show_timeline" do
    it "routes with POST" do
      expect(post("/dashboard/show_timeline")).to route_to("dashboard#show_timeline")
    end
  end

  describe "#tl_generate" do
    it "routes with POST" do
      expect(post("/dashboard/tl_generate")).to route_to("dashboard#tl_generate")
    end
  end

  describe "#wait_for_task" do
    it "routes with POST" do
      expect(post("/dashboard/wait_for_task")).to route_to("dashboard#wait_for_task")
    end
  end

  describe "#widget_add" do
    it "routes with POST" do
      expect(post("/dashboard/widget_add")).to route_to("dashboard#widget_add")
    end
  end

  describe "#widget_close" do
    it "routes with POST" do
      expect(post("/dashboard/widget_close")).to route_to("dashboard#widget_close")
    end
  end

  describe "#widget_dd_done" do
    it "routes with POST" do
      expect(post("/dashboard/widget_dd_done")).to route_to("dashboard#widget_dd_done")
    end
  end

  describe "#widget_toggle_minmax" do
    it "routes with POST" do
      expect(post("/dashboard/widget_toggle_minmax")).to route_to("dashboard#widget_toggle_minmax")
    end
  end

  describe "#widget_zoom" do
    it "routes with POST" do
      expect(post("/dashboard/widget_zoom")).to route_to("dashboard#widget_zoom")
    end
  end

  describe "#window_sizes" do
    it "routes with POST" do
      expect(post("/dashboard/window_sizes")).to route_to("dashboard#window_sizes")
    end
  end

end
