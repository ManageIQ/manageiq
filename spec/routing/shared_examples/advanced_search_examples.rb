shared_examples_for "A controller that has advanced search routes" do |restful|
  describe "#quick_search" do
    it "routes with POST" do
      expect(post("/#{controller_name}/quick_search")).to route_to("#{controller_name}#quick_search")
    end

    if restful
      it "does not route with GET" do
        expect(get("/#{controller_name}/quick_search")).to route_to(:action     => "show",
                                                                    :controller => controller_name,
                                                                    :id         => "quick_search")
      end
    else
      it "does not route with GET" do
        expect(get("/#{controller_name}/quick_search")).not_to be_routable
      end
    end
  end

  describe "#adv_search_button" do
    it "routes with POST" do
      expect(post("/#{controller_name}/adv_search_button")).to route_to("#{controller_name}#adv_search_button")
    end
  end

  describe "#adv_search_clear" do
    it "routes with POST" do
      expect(post("/#{controller_name}/adv_search_clear")).to route_to("#{controller_name}#adv_search_clear")
    end

    if restful
      it "does not route with GET" do
        expect(get("/#{controller_name}/adv_search_clear")).to route_to(:action     => "show",
                                                                        :controller => controller_name,
                                                                        :id         => "adv_search_clear")
      end
    else
      it "does not route with GET" do
        expect(get("/#{controller_name}/adv_search_clear")).not_to be_routable
      end
    end
  end

  describe "#adv_search_toggle" do
    it "routes with POST" do
      expect(post("/#{controller_name}/adv_search_toggle")).to route_to("#{controller_name}#adv_search_toggle")
    end
  end

  describe "#adv_search_load_choice" do
    it "routes with POST" do
      expect(post("/#{controller_name}/adv_search_load_choice")).to route_to(
        "#{controller_name}#adv_search_load_choice"
      )
    end
  end

  describe "#adv_search_name_typed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/adv_search_name_typed")).to route_to("#{controller_name}#adv_search_name_typed")
    end
  end

  describe "#exp_button" do
    it "routes with POST" do
      expect(post("/#{controller_name}/exp_button")).to route_to("#{controller_name}#exp_button")
    end
  end

  describe "#exp_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/exp_changed")).to route_to("#{controller_name}#exp_changed")
    end
  end

  describe "#exp_token_pressed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/exp_token_pressed")).to route_to("#{controller_name}#exp_token_pressed")
    end
  end

  describe "#panel_control" do
    it "routes with POST" do
      expect(post("/#{controller_name}/panel_control")).to route_to("#{controller_name}#panel_control")
    end
  end
end
