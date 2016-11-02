RSpec.shared_examples "a quadicon with a link" do
  it 'renders a quadicon with a link by default' do
    expect(subject.render).to have_selector('div.quadicon')
    expect(subject.render).to have_selector('a')
  end
end

# RSpec.shared_examples :shield_img_with_policies do
#   context "when item has policies" do
#     it 'has a shield icon' do
#       record.add_policy(FactoryGirl.create(:miq_policy))
#
#       expect(subject).to have_selector('img[src*="shield"]')
#     end
#   end
# end
#
# RSpec.shared_examples :host_vendor_icon do |cls|
#   it "renders a quadicon with #{cls}-class vendor img" do
#     vendor = record.vmm_vendor_display.downcase
#     expect(host_quad).to have_selector("div[class*='#{cls}'] img[src*='vendor-#{vendor}']")
#   end
# end

RSpec.shared_examples :no_link_for_listnav do
  before do
    kontext.listnav = true
  end

  it 'has no link when type is listnav' do
    expect(subject).not_to have_selector("a")
  end
end

# RSpec.shared_examples :has_reflection do
#   it 'has a reflection' do
#     expect(subject).to have_selector("img[src*='reflection']")
#   end
# end
#
# RSpec.shared_examples :has_base_img do
#   it 'includes a base-single img' do
#     expect(subject).to have_selector("img[src*='base']")
#     expect(subject).not_to have_selector("img[src*='base-single']")
#   end
# end
#
# RSpec.shared_examples :has_base_single do
#   it 'includes a base-single img' do
#     expect(subject).to have_selector("img[src*='base-single']")
#   end
# end
#
RSpec.shared_examples :has_remote_link do
  it 'builds a remote link' do
    expect(subject).to match(/data-remote/)
    expect(subject).to match(/data-method="post"/)
  end
end

RSpec.shared_examples :has_sparkle_link do
  it 'builds a sparkle link' do
    expect(subject).to match(/data-miq-sparkle-on/)
    expect(subject).to match(/data-miq-sparkle-off/)
  end
end

# RSpec.shared_examples :storage_inferred_url do
#   it 'links to an inferred url' do
#     expect(subject).to have_selector("a[href^='/storage/show']")
#   end
# end
#
# RSpec.shared_examples :storage_name_type_title do
#   it 'has a title with name and type' do
#     expect(subject).to include("Name: #{record.name} | Datastores Type: VMFS")
#   end
# end
#
RSpec.shared_examples :guest_os_icon do
  it 'includes a vendor icon' do
    # expect(subject).to have_selector("img[src*='vendor-openstack']")
    expect(subject.render).to match(/quadrant-guest_os/)
  end
end

RSpec.shared_examples :compliance_passing_quadrant do
  it 'includes image for compliance' do
    allow(record).to receive(:passes_profiles?) { true }
    expect(subject.render).to have_selector("img[src*='check']")
  end
end
