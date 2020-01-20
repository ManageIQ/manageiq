RSpec.describe ActsAsArScope do
  context "AR backed model" do
    # model contains ids of important vms - acts like ar model
    let(:important_vm_model) do
      Class.new(ActsAsArScope) do
        def self.vm_ids
          @vm_ids ||= []
        end

        def self.vm_ids=(new_ids)
          @vm_ids = new_ids
        end

        def self.aar_scope
          Vm.where(:id => vm_ids)
        end
      end
    end

    it "delegates to :aar_scope" do
      good = FactoryBot.create_list(:vm, 3)
      bad = FactoryBot.create_list(:vm, 1)

      important_vm_model.vm_ids += good.map(&:id)

      expect(important_vm_model.all.order(:id)).to eq(good)
      expect(important_vm_model.all.order('id desc').first).to eq(good.last)
      expect(important_vm_model.all.count).to eq(3)
      expect(important_vm_model.first).to eq(good.first)
      expect(important_vm_model.last).to eq(good.last)
      expect(important_vm_model.order(:id => 'desc').first).to eq(good.last)
      expect(important_vm_model.limit(1).order('id desc')).to eq([good.last])
      expect(important_vm_model.offset(good.size - 1).order(:id)).to eq([good.last])
      expect(important_vm_model.where(:id => good.last.id).count).to eq(1)
      expect(important_vm_model.where(:id => bad.last.id).count).to eq(0)
      expect(important_vm_model.includes(:ext_management_system).where(:id => good.last.id).count).to eq(1)
      expect(important_vm_model.order('id desc').first).to eq(good.last)
      expect(important_vm_model.find(good.first.id)).to eq(good.first)
      expect(important_vm_model.find_by(:id => good.first.id)).to eq(good.first)
    end
  end
end
