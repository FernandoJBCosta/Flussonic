Erlmedia
========

Erlmedia is a format library, extracted from Erlyvideo. 
It doesn't and never will decode anything or encode, because erlang isn't suited for such things. Use libavcodec for it.

Erlmedia has a universal header video_frame.hrl, that is used in all erlyvideo related projects.
In src/ lie modules that unpack containers into video_frame and back.


Licensing
=========

Erlmedia is distributed under the MIT license

This product contains components, distributed under other licences:
*  http_uri2.erl under Erlang Public License. You can read it from file doc/EPLICENSE
