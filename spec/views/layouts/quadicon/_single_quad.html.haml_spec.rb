describe "rendering single quadicon for service" do
  before(:each) do
    @settings = {:quadicons => {:service => false}}
    @item = FactoryGirl.build(:service)
    @layout = "service"
  end

  it "doesn't display IP Address in the tooltip" do
    render :partial => "layouts/quadicon/single_quad",
           :locals  => {:size => "72",
                        :typ  => "grid",
                        :item => @item}
  end
end

describe "rendering single quadicon for Orchestration Template type Catalog Item" do
  before(:each) do
    @settings = {:quadicons => {:service_template => false}}
    @item = FactoryGirl.build(:service_template_orchestration)
    @layout = "service"
  end

  it "doesn't display IP Address in the tooltip" do
    render :partial => "layouts/quadicon/single_quad",
           :locals  => {:size => "72",
                        :typ  => "grid",
                        :item => @item}
  end
end
