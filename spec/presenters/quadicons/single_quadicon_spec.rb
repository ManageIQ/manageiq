describe Quadicons::SingleQuadicon, :type => :helper do
  let(:record) { FactoryGirl.create(:configuration_manager_foreman) }
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::SingleQuadicon.new(record, kontext) }

  before do
    kontext.embedded = false
    kontext.explorer = true

    allow(controller).to receive(:list_row_id).with(record) do
      ApplicationRecord.compress_id(record.id)
    end

    allow(controller).to receive(:default_url_options) do
      {:controller => "provider_foreman"}
    end
  end

  describe "Setup" do
    subject(:quadicon) { instance }

    it 'includes a type icon quadrant' do
      expect(quadicon.quadrant_list).to include(:type_icon)
    end
  end

  describe "Rendering" do
    subject(:rendered) { instance.render }

    context "when not listicon" do
      before do
        kontext.listicon = false
      end

      context "when record is decorated" do
        context "when item is a config manager foreman" do
          it 'includes a vendor listicon img' do
            expect(rendered).to have_selector("img[src*='vendor-#{item.image_name}']")
          end
        end

        context "when item is a middleware deployment" do
          let(:record) { FactoryGirl.create(:middleware_deployment) }

          it 'includes a vendor listicon img' do
            expect(rendered).to have_selector("img[src*='middleware_deployment']")
          end
        end
      end
    end
  end

  context "when @listicon is nil" do
    # context "when item is decorated" do
    #   context "when item is a config manager foreman" do
    #     it 'includes a vendor listicon img' do
    #       expect(rendered).to have_selector("img[src*='vendor-#{item.image_name}']")
    #     end
    #   end
    #
    #   context "when item is a middleware deployment" do
    #     let(:record) { FactoryGirl.create(:middleware_deployment) }
    #
    #     it 'includes a vendor listicon img' do
    #       expect(rendered).to have_selector("img[src*='middleware_deployment']")
    #     end
    #   end
    # end

    # context "when item is not CIM or decorated" do
    #   before(:each) do
    #     allow(item).to receive(:decorator_class?) { false }
    #   end
    #
    #   it "includes an image with the item's base class name" do
    #     name = item.class.base_class.to_s.underscore
    #     expect(single_quad).to have_selector("img[src*='#{name}']")
    #   end
    # end

    # context "when type is not :listnav" do
    #   # context "when not embedded" do
    #   #   # context "when explorer" do
    #   #   #   before(:each) do
    #   #   #     @explorer = true
    #   #   #   end
    #   #   #
    #   #   #   include_examples :has_sparkle_link
    #   #   #
    #   #   #   it 'links to x_show with compressed id' do
    #   #   #     cid = ApplicationRecord.compress_id(item.id)
    #   #   #     expect(subject).to have_selector("a[href*='x_show/#{cid}']")
    #   #   #   end
    #   #   # end
    #   #
    #   #   # context "when not explorer" do
    #   #   #   # FIXME: This branch will error if item is Configuration Manager,
    #   #   #   # a bug to be handled in this refactoring
    #   #   #   #
    #   #   #   let(:item) { FactoryGirl.create(:middleware_deployment) }
    #   #   #
    #   #   #   before(:each) do
    #   #   #     @explorer = false
    #   #   #   end
    #   #   #
    #   #   #   it 'links to the record' do
    #   #   #     cid = ApplicationRecord.compress_id(item.id)
    #   #   #     expect(subject).to have_selector("a[href*='#{cid}']")
    #   #   #   end
    #   #   # end
    #   # end
    #
    #   # context "when embedded" do
    #   #   before(:each) do
    #   #     @embedded = true
    #   #   end
    #   #
    #   #   it 'links to nowhere' do
    #   #     expect(single_quad).to have_selector("a[href='']")
    #   #   end
    #   # end
    # end
  end # => when @listicon is nil

  context "when listicon is not nil" do
    # before(:each) do
    #   @listicon = "foo"
    #   @parent = FactoryGirl.build(:vm_vmware)
    # end
    #
    # include_examples :has_base_single
    #
    # it 'includes a listicon image' do
    #   expect(single_quad).to have_selector("img[src*='foo']")
    # end
    #
    # context "when listicon is scan_history" do
    #   let(:item) { ScanHistory.new(:started_on => Time.zone.today) }
    #
    #   before(:each) do
    #     @listicon = "scan_history"
    #   end
    #
    #   it 'titles based on the item started_on' do
    #     expect(single_quad).to include("title=\"#{item.started_on}\"")
    #   end
    # end
    #
    # context "when listicon is orchestration_stack_output" do
    #   let(:item) { OrchestrationStackOutput.new(:key => "Bar") }
    #
    #   before(:each) do
    #     @listicon = "orchestration_stack_output"
    #   end
    #
    #   it 'titles based on the item key' do
    #     expect(single_quad).to include("title=\"Bar\"")
    #   end
    # end
  end
end
