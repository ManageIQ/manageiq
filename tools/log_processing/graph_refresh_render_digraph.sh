#!/bin/bash

# During graph refresh something like this is printed to log:
# ... Topological sorting of manager ... resulted in these layers ...:
# digraph {
#   ...
# }

# This is suggested command to render a pretty graph from it.
# Requires Graphviz installed.

echo 'Paste the lines from `digraph {` to `}` inclusive on stdin.'

set -v

# unflatten's -l2 flag is arbitrary heuristic, might be better without.
unflatten -l2 -f |
  dot -Gstyle=dotted -Grankdir=LR -Granksep=1 -Gfontname=sans -Nshape=box -Nstyle=rounded -Ncolor=gray -Nfontname=monospace |
  edgepaint |
  dot -Tsvg -o refresh-graph.svg

xdg-open refresh-graph.svg
