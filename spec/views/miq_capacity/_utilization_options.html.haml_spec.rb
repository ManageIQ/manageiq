require "spec_helper"
include ApplicationHelper

describe "miq_capacity/_utilization_options.html.haml" do
  before :each do
    set_controller_for_view("miq_capacity")
    assign(:record, Struct.new("Record", :id).new(2))
    assign(:sb, {:util => {:options => {:days         => 2,
                                        :time_profile => "1",
                                        :chart_date   => "asdf"
                                       },
                           :tags    => {:asdf => "fdsa"}
                          }
                }
          )
  end
  it "check if correct fields are being displayed if cap_type is not set" do
    # render with default cap_type variable value
    render :partial => "miq_capacity/utilization_options",
           :locals  => {:cap_type => nil}
  end
  it "check if correct fields are being displayed if cap_type is set" do
    response.should_not have_selector('label', :text => 'Selected Day')
    # render with cap_type variable set
    render :partial => "miq_capacity/utilization_options",
           :locals  => {:cap_type => "summ"}
    response.should have_selector('label', :text => 'Selected Day')
  end
end
