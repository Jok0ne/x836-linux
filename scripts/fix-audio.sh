#!/bin/bash
sleep 5
amixer -c 0 cset name='Speaker Switch' on
amixer -c 0 cset name='Headphone Switch' on
amixer -c 0 cset name='Headphone Playback Volume' 3,3
amixer -c 0 cset name='Right Headphone Mixer Right DAC Switch' on
amixer -c 0 cset name='Left Headphone Mixer Left DAC Switch' on
amixer -c 0 cset name='DAC Playback Volume' 192,192
amixer -c 0 cset name='Headphone Mixer Volume' 11,11
