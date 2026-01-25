#!/bin/bash
# Quits running EnputPlus so you can update it

if pgrep -x "EnputPlus" > /dev/null; then
    killall EnputPlus
    echo "EnputPlus stopped."
    echo "Now drag EnputPlus.app to Input Methods folder."
else
    echo "EnputPlus is not running."
fi

echo ""
read -n 1 -s -r -p "Press any key to close..."
