shared_examples 'TreeNode::Node#key prefix' do |prefix|
  describe '#key' do
    it "begins with #{prefix}" do
      expect(subject.key).to start_with(prefix)
    end
  end
end

shared_examples 'TreeNode::Node#image' do |image|
  describe '#image' do
    it "returns with #{image}" do
      expect(subject.image).to eq(image)
    end
  end
end

shared_examples 'TreeNode::Node#tooltip same as #title' do
  describe '#tooltip' do
    it 'returns the same as node title' do
      expect(subject.tooltip).to eq(subject.title)
    end
  end
end

shared_examples 'TreeNode::Node#tooltip prefix' do |prefix|
  describe '#tooltip' do
    it 'returns the prefixed title' do
      expect(subject.tooltip).to eq("#{prefix}: #{subject.title}")
    end
  end
end

shared_examples 'TreeNode::Node#title description' do
  describe '#title' do
    it 'returns with the object description' do
      expect(subject.title).to eq(object.description)
    end
  end
end
