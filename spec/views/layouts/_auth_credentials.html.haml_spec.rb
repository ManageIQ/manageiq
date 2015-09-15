require "spec_helper"

describe "layouts/_auth_credentials.html.haml" do
  it "check if correct labels are being displayed for credentials fields" do
    set_controller_for_view("host")
    assign(:edit, :new => {})
    render :partial => "layouts/auth_credentials",
           :locals  => {:uid_label => "Access Key ID",
                        :pwd_label => "Secret Access Key"}
    response.should have_selector('label', :text => 'Access Key ID')
    response.should have_selector('label', :text => 'Secret Access Key')
    response.should have_selector('label', :text => 'Verify Secret Access Key')

    render
    # showing default labels
    response.should have_selector('label', :text => 'Username')
    response.should have_selector('label', :text => 'Password')
    response.should have_selector('label', :text => 'Verify Password')
  end
end
