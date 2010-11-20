#!/bin/bash
mencoder tv:// -tv driver=v4l2:width=320:height=240:fps=30:device=/dev/video0 -nosound -ovc lavc -lavcopts vcodec=mpeg4:vbitrate=1800:vhq:keyint=250 -o /opt/scripts/bamboo_punisher/missile_log.avi
