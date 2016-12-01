describe Quadicons::VmOrTemplateUrlBuilder, :type => :helper do
  let(:record) { FactoryGirl.create(:vm_redhat) }
  let(:kontext) { Quadicons::Context.new(helper) }

  describe "vm_link_attributes" do
    subject do
      Quadicons::VmOrTemplateUrlBuilder.new(record, kontext).vm_link_attributes
    end

    before do
      allow(helper).to receive(:role_allows) { true }
    end

    context "record is a cloud vm" do
      let(:record) { FactoryGirl.create(:vm_cloud) }

      it 'links to vm_cloud' do
        expect(subject[:controller]).to eq("vm_cloud")
      end
    end

    context "record is an infra vm" do
      let(:record) { FactoryGirl.create(:vm_infra) }

      it 'links to vm_infra' do
        expect(subject[:controller]).to eq("vm_infra")
      end
    end
  end

  describe 'url' do
    subject(:url) do
      Quadicons::VmOrTemplateUrlBuilder.new(record, kontext).url
    end

    context "when not embedded" do
      before do
        kontext.embedded = false
      end

      context "when in explorer view" do
        before do
          kontext.explorer = true
        end

        context "when service controller and Vm view" do
          before do
            kontext.view = FactoryGirl.build(:miq_report)
            kontext.controller = "service"
          end

          context "and when url can be found with vm_quad_link_attributes" do
            before do
              allow(helper).to receive(:role_allows).and_return(true)
            end

            it 'builds the link based on attributes' do
              expect(url).to match(/vm_infra/)
              expect(url).to match(/#{record.id}/)
            end
          end

          context "and when url cannot be found with vm_quad_link_attributes" do
            it 'links to nowhere' do
              expect(url).to eq("")
            end
          end
        end

        context "when not in service controller" do
          before do
            # because quadicon_vm_attributes_present? can be true
            allow(helper).to receive(:role_allows).and_return(true)
          end

          it 'links to x_show' do
            cid = ApplicationRecord.compress_id(record.id)
            expect(url).to match(/x_show/)
            expect(url).to match(/#{cid}/)
          end
        end
      end

      context "when not in explorer view" do
        before(:each) do
          kontext.explorer = false
        end

        it 'links to the record' do
          expect(url).to match(%r{vm_infra/show})
        end
      end
    end

    context "when embedded" do
      before(:each) do
        kontext.embedded = true
        kontext.showlinks = false
        kontext.explorer = false
      end

      context "when in policy simulator" do
        before(:each) do
          kontext.policy_sim = true
          kontext.policies = {:foo => :bar}
          allow(record).to receive(:passes_profiles?) { true }
        end

        it 'links to policies action with cid' do
          cid = ApplicationRecord.compress_id(record.id)
          # expect(subject).to have_selector("a[href*='policies/#{cid}']")
          expect(url).to match(/policies/)
          expect(url).to match(/#{cid}/)
        end
      end

      context "when not in policy simulator" do
        before do
          kontext.policy_sim = false
        end

        it 'links to the inferred url' do
          expect(controller).to receive(:default_url_options) do
            { :controller => "vm_infra" }
          end

          expect(url).to match(/vm_infra/)
        end
      end
    end
  end
end
