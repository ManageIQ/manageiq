shared_examples_for "A controller that has compare routes" do
  describe "#compare_compress" do
    it "routes with POST" do
      expect(post("/#{controller_name}/compare_compress")).to route_to("#{controller_name}#compare_compress")
    end
  end

  describe "#compare_choose_base" do
    it "routes with POST" do
      expect(post("/#{controller_name}/compare_choose_base")).to route_to(
                                                                    "#{controller_name}#compare_choose_base")
    end
  end

  describe "#compare_remove" do
    it "routes with POST" do
      expect(post("/#{controller_name}/compare_remove")).to route_to(
                                                                "#{controller_name}#compare_remove")
    end
  end

  describe "#compare_miq" do
    it "routes with GET" do
      expect(get("/#{controller_name}/compare_miq")).to route_to("#{controller_name}#compare_miq")
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/compare_miq")).to route_to("#{controller_name}#compare_miq")
    end
  end

  describe "#compare_miq_all" do
    it "routes with POST" do
      expect(post("/#{controller_name}/compare_miq_all")).to route_to("#{controller_name}#compare_miq_all")
    end
  end

  describe "#compare_miq_differences" do
    it "routes with POST" do
      expect(post("/#{controller_name}/compare_miq_differences")).to route_to("#{controller_name}#compare_miq_differences")
    end
  end

  describe "#compare_miq_same" do
    it "routes with POST" do
      expect(post("/#{controller_name}/compare_miq_same")).to route_to("#{controller_name}#compare_miq_same")
    end
  end

  describe "#compare_mode" do
    it "routes with POST" do
      expect(post("/#{controller_name}/compare_mode")).to route_to("#{controller_name}#compare_mode")
    end
  end

  describe "#compare_remove" do
    it "routes with POST" do
      expect(post("/#{controller_name}/compare_remove")).to route_to("#{controller_name}#compare_remove")
    end
  end

  describe "#compare_set_state" do
    it "routes with POST" do
      expect(post("/#{controller_name}/compare_set_state")).to route_to("#{controller_name}#compare_set_state")
    end
  end

  describe "#compare_to_csv" do
    it "routes with GET" do
      expect(get("/#{controller_name}/compare_to_csv")).to route_to("#{controller_name}#compare_to_csv")
    end
  end

  describe "#compare_to_pdf" do
    it "routes with GET" do
      expect(get("/#{controller_name}/compare_to_pdf")).to route_to("#{controller_name}#compare_to_pdf")
    end
  end

  describe "#compare_to_txt" do
    it "routes with GET" do
      expect(get("/#{controller_name}/compare_to_txt")).to route_to("#{controller_name}#compare_to_txt")
    end
  end
end
