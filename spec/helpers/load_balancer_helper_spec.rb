describe LoadBalancerHelper do
  context "::display_protocol_port_range" do
    it "should display protocol and a single port" do
      expect(LoadBalancerHelper.display_protocol_port_range("TCP", 80..80)).to eq("TCP:80")
    end

    it "should display protocol and a range of ports" do
      expect(LoadBalancerHelper.display_protocol_port_range("UDP", 80..100)).to eq("UDP:80-100")
    end
  end

  context "::display_port_range" do
    it "should display an empty range as an empty string" do
      expect(LoadBalancerHelper.display_port_range(11...11)).to eq("")
    end

    it "should display a nil range as nil" do
      expect(LoadBalancerHelper.display_port_range(nil)).to eq("nil")
    end

    it "should display a range of size 1 as a single port" do
      expect(LoadBalancerHelper.display_port_range(60..60)).to eq("60")
    end

    it "should display a range of size > 1 as an inclusive range" do
      expect(LoadBalancerHelper.display_port_range(60..80)).to eq("60-80")
    end

    it "should display a range of size > 1 with exclusive endpoint as inclusive range" do
      expect(LoadBalancerHelper.display_port_range(60...81)).to eq("60-80")
    end
  end
end
