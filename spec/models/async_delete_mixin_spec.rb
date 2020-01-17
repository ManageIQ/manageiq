RSpec.describe AsyncDeleteMixin do
  def common_setup(klass)
    objects = []
    3.times do |i|
      obj = FactoryBot.create(klass, :name => "test_#{klass}_#{i}")
      objects << obj
    end

    return objects, objects.first
  end

  def self.should_define_destroy_queue_instance_method
    it "should define destroy_queue instance method" do
      expect(@obj.respond_to?(:destroy_queue)).to be_truthy, "instance method destroy_queue not defined for #{@obj.class.name}"
    end
  end

  def self.should_define_destroy_queue_class_method
    it "should define destroy_queue class method" do
      expect(@obj.class.respond_to?(:destroy_queue)).to be_truthy, "class method destroy_queue not defined for #{@obj.class.name}"
    end
  end

  def self.should_define_delete_queue_instance_method
    it "should define delete_queue instance method" do
      expect(@obj.respond_to?(:delete_queue)).to be_truthy, "instance method delete_queue not defined for #{@obj.class.name}"
    end
  end

  def self.should_define_delete_queue_class_method
    it "should define delete_queue class method" do
      expect(@obj.class.respond_to?(:delete_queue)).to be_truthy, "class method delete_queue not defined for #{@obj.class.name}"
    end
  end

  def self.should_queue_destroy_on_instance(queue_method = "destroy")
    it "should queue up destroy on instance" do
      cond = ["class_name = ? AND instance_id = ? AND method_name = ?", @obj.class.name, @obj.id, queue_method]

      expect { @obj.destroy_queue }.not_to raise_error
      expect(MiqQueue.where(cond).count).to eq(1)
      expect_any_instance_of(@obj.class).to receive(:destroy).once

      queue_message = MiqQueue.where(cond).first
      status, message, result = queue_message.deliver
      queue_message.delivered(status, message, result)
      expect(queue_message.state).to eq("ok")
    end
  end

  def self.should_queue_destroy_on_class_with_many_ids(queue_method = "destroy")
    it "should queue up destroy on class method with many ids" do
      ids = @objects.collect(&:id)
      cond = ["class_name = ? AND instance_id in (?) AND method_name = ?", @obj.class.name, ids, queue_method]

      expect { @obj.class.destroy_queue(ids) }.not_to raise_error
      expect(MiqQueue.where(cond).count).to eq(ids.length)
      count = @obj.class.count

      queue_messages = MiqQueue.where(cond)
      queue_messages.each do |queue_message|
        status, message, result = queue_message.deliver
        queue_message.delivered(status, message, result)
        expect(queue_message.state).to eq("ok")
      end
      expect(@obj.class.count).to eq(count - ids.length)
    end
  end

  def self.should_queue_delete_on_instance
    it "should queue up delete on instance" do
      cond = ["class_name = ? AND instance_id = ? AND method_name = ?", @obj.class.name, @obj.id, "delete"]

      expect { @obj.delete_queue }.not_to raise_error
      expect(MiqQueue.where(cond).count).to eq(1)
      expect_any_instance_of(@obj.class).to receive(:delete).once

      queue_message = MiqQueue.where(cond).first
      status, message, result = queue_message.deliver
      queue_message.delivered(status, message, result)
      expect(queue_message.state).to eq("ok")
    end
  end

  def self.should_queue_delete_on_class_with_many_ids
    it "should queue up delete on class method with many ids" do
      ids = @objects.collect(&:id)
      cond = ["class_name = ? AND instance_id in (?) AND method_name = ?", @obj.class.name, ids, "delete"]

      expect { @obj.class.delete_queue(ids) }.not_to raise_error
      expect(MiqQueue.where(cond).count).to eq(ids.length)
      count = @obj.class.count

      queue_messages = MiqQueue.where(cond)
      queue_messages.each do |queue_message|
        status, message, result = queue_message.deliver
        queue_message.delivered(status, message, result)
        expect(queue_message.state).to eq("ok")
      end
      expect(@obj.class.count).to eq(count - ids.length)
    end
  end

  context "with zone and server" do
    before do
      EvmSpecHelper.local_miq_server
    end

    context "with 3 ems clusters" do
      before do
        @objects, @obj = common_setup(:ems_cluster)
      end

      should_define_destroy_queue_instance_method
      should_define_destroy_queue_class_method
      should_queue_destroy_on_instance
      should_queue_destroy_on_class_with_many_ids

      should_define_delete_queue_instance_method
      should_define_delete_queue_class_method
      should_queue_delete_on_instance
      should_queue_delete_on_class_with_many_ids
    end

    context "with 3 ems" do
      before do
        @objects, @obj = common_setup(:ems_vmware)
      end

      should_define_destroy_queue_instance_method
      should_define_destroy_queue_class_method
      should_queue_destroy_on_instance
      should_queue_destroy_on_class_with_many_ids

      should_define_delete_queue_instance_method
      should_define_delete_queue_class_method
      should_queue_delete_on_instance
      should_queue_delete_on_class_with_many_ids
    end

    context "with 3 hosts" do
      before do
        @objects, @obj = common_setup(:host)
      end

      should_define_destroy_queue_instance_method
      should_define_destroy_queue_class_method
      should_queue_destroy_on_instance
      should_queue_destroy_on_class_with_many_ids

      should_define_delete_queue_instance_method
      should_define_delete_queue_class_method
      should_queue_delete_on_instance
      should_queue_delete_on_class_with_many_ids
    end

    context "with 3 resource pools" do
      before do
        @objects, @obj = common_setup(:resource_pool)
      end

      should_define_destroy_queue_instance_method
      should_define_destroy_queue_class_method
      should_queue_destroy_on_instance
      should_queue_destroy_on_class_with_many_ids

      should_define_delete_queue_instance_method
      should_define_delete_queue_class_method
      should_queue_delete_on_instance
      should_queue_delete_on_class_with_many_ids
    end

    context "with 3 storages" do
      before do
        @objects, @obj = common_setup(:storage)
      end

      should_define_destroy_queue_instance_method
      should_define_destroy_queue_class_method
      should_queue_destroy_on_instance
      should_queue_destroy_on_class_with_many_ids

      should_define_delete_queue_instance_method
      should_define_delete_queue_class_method
      should_queue_delete_on_instance
      should_queue_delete_on_class_with_many_ids
    end
  end
end
