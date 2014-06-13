$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext3
		
	# ////////////////////////////////////////////////////////////////////////////
	# // Data definitions.

	HASH_TREE_ENTRY_FIRST = [
		'S',	'max_descriptors',	# Maximum number of node descriptors.
		'S',	'cur_descriptors',	# Current number of node descriptors.
		'L',	'first_node',				# Block address of first node.
	]

	HASH_TREE_ENTRY_NEXT = [
		'L',	'min_hash',		# Minimum hash value in node.
		'L',	'next_node',	# Block address of next node.
	]

	class HashTreeEntry


	end
end
