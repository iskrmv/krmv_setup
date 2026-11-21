#!/bin/sh
# App launcher (ALT + SPACE, or the button in the bar).
# Type letters: apps that START with them come first, looser guesses below.
# Not an app? Type  run <command>  (for example  run btop  or  run tork)  and press Enter.
exec rofi -show drun -mesg "Not an app?  Type:  run <command>   (terminal tools: run btop, run tork)"
