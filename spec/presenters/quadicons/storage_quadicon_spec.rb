require "presenters/quadicons/quadicon_shared_specs"

# RSpec.shared_examples :shows_free_space do
#   it 'shows free space' do
#     expect(quadicon.quadrant_list).to include(:storage_usage)
#   end
# end

describe Quadicons::StorageQuadicon, :type => :helper do
  let(:record) do
    FactoryGirl.create(
      :storage,
      :store_type  => "VMFS",
      :total_space => 1000,
      :free_space  => 250
    )
  end

  let(:kontext) { Quadicons::Context.new(helper) }

  subject(:quadicon) { Quadicons::StorageQuadicon.new(record, kontext) }

  context "when storage is true in settings" do
    before do
      kontext.settings = { :quadicons => {:storage => true} }
    end

    # Tests that quadrant classes exist and are constantized
    it 'collects 4 quadrant classes' do
      expect(quadicon.quadrant_classes.compact.count).to eq(4)
    end

    it 'includes the storage_type' do
      expect(quadicon.quadrant_list).to include(:storage_type)
    end

    it 'shows free space' do
      expect(quadicon.quadrant_list).to include(:storage_free_space)
    end

    it 'shows a count of vms' do
      expect(quadicon.quadrant_list).to include(:guest_count)
    end

    it 'shows a count of hosts' do
      expect(quadicon.quadrant_list).to include(:host_count)
    end
  end

  context "when storage is falsey in settings" do
    before do
      kontext.settings = { :quadicons => {:storage => false} }
    end

    it 'shows used space' do
      expect(quadicon.quadrant_list).to include(:storage_used_space)
    end

    it 'renders in single mode' do
      expect(quadicon.render_single?).to eq(true)
    end
  end

  context "when listnav" do
    before do
      kontext.listnav = true
    end

    it 'does not render an anchor tag' do
      expect(quadicon.render).not_to have_selector("a")
    end

    # TODO: Is this intention or just how it happened?
    # it 'does not have name and type in title' do
    #   expect(quadicon.render).not_to include("Datastores Type: VMFS")
    # end
  end

  context "when not in listnav" do
    before do
      kontext.listnav = false
    end

    it 'has a title with name and type' do
      expect(quadicon.render).to include("Name: #{record.name} | Datastores Type: VMFS")
    end
  end
end
