# require Rails.root.join('spec', 'presenters', 'quadicons', 'quadicon_shared_specs.rb')
require "presenters/quadicons/quadicon_shared_specs"

# RSpec.shared_examples "a quadicon with a link" do
#   it 'renders a quadicon with a link by default' do
#     expect(subject.render).to have_selector('div.quadicon')
#     expect(subject.render).to have_selector('a')
#   end
# end

describe Quadicons::VmOrTemplateQuadicon, :type => :helper do
  subject(:quadicon) { Quadicons::VmOrTemplateQuadicon.new(record, kontext) }

  # As far as I can tell, the view env will always have
  # settings[:quadicons][:vm] set to true.
  #
  let(:kontext) do
    Quadicons::Context.new(helper) do |c|
      c.settings = { :quadicons => {:vm => true} }
    end
  end

  let(:record) { FactoryGirl.create(:vm_vmware) }

  it 'builds an array of Quadrants' do
    expect(quadicon.quadrants).not_to be_empty
    expect(quadicon.quadrant_classes.first).to be_a_kind_of(Quadicons::Quadrants::Base)
  end

  it 'determines the proper base model name' do
    expect(subject.record_class).to eq(:vm)
  end

  describe "rendering" do
    it_behaves_like "a quadicon with a link"

    it 'includes a label' do
      expect(quadicon.render).to match(/quadicon-label/)
    end

    context "render all quadrants" do
      it 'knows to render in full mode' do
        expect(quadicon.render_full?).to be true
      end

      it 'includes the guest os icon' do
        expect(quadicon.render).to match(/os-unknown/)
      end

      it 'includes a vm state icon' do
        expect(quadicon.render).to match(/currentstate/)
      end

      it 'includes the host vendor icon' do
        expect(quadicon.render).to match(/vendor-vmware/)
      end

      it 'includes a policy shield' do
        record.add_policy(FactoryGirl.create(:miq_policy))
        expect(quadicon.render).to have_selector('img[src*="shield"]')
      end

      context "when lastaction is policy_sim" do
        before do
          kontext.lastaction = "policy_sim"
        end

        it 'does not include the snapshot count' do
          expect(quadicon.quadrant_list).not_to include(:snapshot_count)
        end

        context "and context policy_sim is truthy and context policies is not empty" do
          before do
            kontext.policy_sim = true
            kontext.policies = { :foo => :bar }
            allow(record).to receive(:passes_profiles?) { true }
          end

          it 'includes a compliance icon' do
            expect(quadicon.quadrant_list).to include(:guest_compliance)
            expect(quadicon.render).to have_selector("img[src*='check']")
          end
        end

        context "when context policy_sim is not truthy" do
          before do
            kontext.policy_sim = false
          end

          it 'does not include a compliance badge' do
            expect(quadicon.quadrant_list).not_to include(:guest_compliance)
            expect(quadicon.render).not_to have_selector("img[src*='check']")
          end
        end
      end

      context "when lastaction is not policy_sim" do
        before do
          kontext.lastaction = "foo"
        end

        it 'includes the total snapshot count' do
          expect(quadicon.quadrant_list).to include(:snapshot_count)
          expect(quadicon.render).to match(/quadrant-snapshot/)
        end
      end
    end

    # TODO: Remove this functionality
    # I don't believe this branch is entered anymore --ehayes July 2016
    #
    context "render as single" do
      let(:kontext) do
        Quadicons::Context.new(helper) do |c|
          c.settings = nil
        end
      end

      it 'knows to render in single-mode' do
        expect(quadicon.render_single?).to be true
      end

      context "when policy_sim" do
        before do
          kontext.policy_sim = true
          kontext.policies = {:foo => :bar}
          allow(record).to receive(:passes_profiles?) { true }
        end

        # Originally this branch would render a "single" quadicon
        # but 2 images would end up in the output. (it didn't work)
        # Currently full quadicons are rendered for
        # policy simulations.

        include_examples :compliance_passing_quadrant

        it 'has a single-mode returning a compliance quadrant' do
          expect(quadicon.quadrants).to eq([:guest_compliance])
        end
      end

      context "when not policy_sim" do
        include_examples :guest_os_icon
      end
    end

    context "when type is not listnav" do
      context "when not embedded" do
        before do
          kontext.embedded = false
        end

        context "when not in explorer view" do
          before do
            kontext.explorer = false
          end

          it 'links to the record' do
            expect(quadicon.render).to have_selector("a[href^='/vm_infra/show']")
          end
        end
      end

      context "when embedded" do
        before do
          kontext.embedded = true
          kontext.showlinks = false
          kontext.explorer = false
        end

        context "when @policy_sim" do
          before do
            kontext.policy_sim = true
            kontext.policies = {:foo => :bar}
            allow(record).to receive(:passes_profiles?) { true }
          end

          context "and when @edit or @edit[:explorer] is not present" do
            it 'includes a policy detail title attribute' do
              expect(quadicon.render).to include("Show policy details for")
            end

            it 'links to policies action with cid' do
              cid = ApplicationRecord.compress_id(record.id)
              expect(quadicon.render).to have_selector("a[href*='policies/#{cid}']")
            end
          end
        end

        context "when @policy_sim is falsey" do
          before do
            kontext.policy_sim = false
            allow(controller).to receive(:default_url_options) do
              {:controller => "vm_infra", :action => "show"}
            end
          end

          it 'links to an inferred url' do
            expect(quadicon.render).to have_selector("a[href^='/vm_infra/show']")
          end
        end
      end
    end

    context "when type is listnav" do
      before do
        kontext.listnav = true
      end

      include_examples :no_link_for_listnav
    end
  end
end
