require "spec_helper"

describe "layouts/_auth_credentials.html.haml" do
  it "check if correct labels are being displayed for credentials fields" do
    set_controller_for_view("host")
    assign(:edit, :new => {})
    render :partial => "layouts/auth_credentials",
           :locals  => {:uid_label => "Access Key ID",
                        :pwd_label => "Secret Access Key"}
    expect(response).to have_selector('label', :text => 'Access Key ID')
    expect(response).to have_selector('label', :text => 'Secret Access Key')
    expect(response).to have_selector('label', :text => 'Confirm Secret Access Key')

    render
    # showing default labels
    expect(response).to have_selector('label', :text => 'Username')
    expect(response).to have_selector('label', :text => 'Password')
    expect(response).to have_selector('label', :text => 'Confirm Password')
  end
end
