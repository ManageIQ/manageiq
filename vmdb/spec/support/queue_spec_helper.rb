module QueueSpecHelper
  # auto deliver queue methods (to avoid using a worker)
  # you can pass in a requester, or provide a block that will determine the requester
  def auto_deliver_queue(default_requester = nil)
    queue_put = MiqQueue.method(:put)
    expect(MiqQueue).to receive(:put) do |*args|
      msg = queue_put.call(*args)
      requester = block_given? && yield(msg) || default_requester
      msg.deliver(requester)
    end
  end
end
