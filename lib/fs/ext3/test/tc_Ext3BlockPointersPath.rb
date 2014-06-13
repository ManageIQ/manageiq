require 'test/unit'
require 'enumerator'

$:.push("#{File.dirname(__FILE__)}/..")
require 'Ext3BlockPointersPath'
include  Ext3

class TestBlockPointersPath < Test::Unit::TestCase

  NUM_INDIRECTS = 15
  MAX_BLOCK = 3626

  EXPECTED = [
    0,    [0,  nil, nil, nil], :direct,

    11,   [11, nil, nil, nil], :direct,
    12,   [12,   0, nil, nil], :single_indirect,
    13,   [12,   1, nil, nil], :single_indirect,

    26,   [12,  14, nil, nil], :single_indirect,
    27,   [13,   0,   0, nil], :double_indirect,
    28,   [13,   0,   1, nil], :double_indirect,

    41,   [13,   0,  14, nil], :double_indirect,
    42,   [13,   1,   0, nil], :double_indirect,

    251,  [13,  14,  14, nil], :double_indirect,
    252,  [14,   0,   0,   0], :triple_indirect,
    253,  [14,   0,   0,   1], :triple_indirect,

    266,  [14,   0,   0,  14], :triple_indirect,
    267,  [14,   0,   1,   0], :triple_indirect,

    476,  [14,   0,  14,  14], :triple_indirect,
    477,  [14,   1,   0,   0], :triple_indirect,

    MAX_BLOCK, [14,  14,  14,  14], :triple_indirect
  ]

	def test_block_set
    path = BlockPointersPath.new(NUM_INDIRECTS)

    assert_raise(ArgumentError) { path.block = -1 }
    assert_raise(ArgumentError) { path.block = MAX_BLOCK + 1 }

    EXPECTED.each_slice(3) do |block, path_a, type|
      path.block = block
      assert_equal block, path.block
      assert_equal path_a, path.to_a
      assert_equal type, path.index_type
    end
	end

  def test_succ!
    path = BlockPointersPath.new(NUM_INDIRECTS)

    EXPECTED.each_slice(3) do |block, path_a, type|
      path.succ! until path.block == block
      assert_equal block, path.block
      assert_equal path_a, path.to_a
      assert_equal type, path.index_type
      break if block == MAX_BLOCK
    end

    assert_raise(RangeError) { path.succ! }
  end

  def test_path_to_block
    path = BlockPointersPath.new(NUM_INDIRECTS)

    EXPECTED.each_slice(3) do |block, path_a, type|
      path.block = block
      assert_equal block, path.send(:path_to_block)
    end
  end
end
