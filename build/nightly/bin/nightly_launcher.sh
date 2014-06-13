#!/bin/bash

nohup $NIGHTLY_BUILD_DIR/schedule.rb 0<&- &>/dev/null &
