%%% @author     Max Lapshin <max@maxidoors.ru> [http://erlyvideo.org]
%%% @copyright  2010-2012 Max Lapshin
%%% @doc        media handler
%%% @reference  See <a href="http://erlyvideo.org" target="_top">http://erlyvideo.org</a> for more information
%%% @end
%%%
%%%
%%% This file is part of erlyvideo.
%%% 
%%% erlmedia is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU General Public License as published by
%%% the Free Software Foundation, either version 3 of the License, or
%%% (at your option) any later version.
%%%
%%% erlmedia is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with erlmedia.  If not, see <http://www.gnu.org/licenses/>.
%%%
%%%---------------------------------------------------------------------------------------
-module(flussonic).
-author('Max Lapshin <max@maxidoors.ru>').


-export([start/0, main/1, test/0]).

main(["-h"]) ->
  io:format(
"Flussonic streaming server http://flussonic.com/ \
Usage: 
-h  for help
-e automatically extract default config files if non found
-c [config path] specify path to config
");

main(["-e"]) ->
  static_file:load_escript_files(),
  io:format("Autoextracting config~n"),
  flu:extract_config_if_required(),
  ok;
  
main(Options) ->
  erlang:set_cookie(node(), 'erlyvideo'),
  static_file:load_escript_files(),
  case flu_config:lookup_config() of
    {error, _} ->
      io:format("No config found, extracting default~n"),
      flu:extract_config_if_required();
    {ok, _, _} ->
      ok
  end,
  io:format("Licensed code loaded~n"),
  ok = start(Options),
  io:format("Flussonic streaming server started. ~nInformation: http://flussonic.com/ (http://erlyvideo.org/)~nContacts: Max Lapshin <info@erlyvideo.org>~n"),
  io:get_line(""),
  io:format("Flussonic is exiting due to user keypress~n").
  

start() ->
  start([]).
  
start(_Options) ->
  application:start(compiler),
  application:load(lager),
  application:set_env(lager,handlers,[{lager_console_backend,info}]),
  application:set_env(lager,error_logger_redirect,true),
  lager:start(),
  license_client:load(),
	application:start(sasl),
	start_app(mimetypes),
  start_app(cowboy),
	start_app(rtmp),
	start_app(rtp),
	start_app(rtsp),
	start_app(gen_tracker),
	start_app(os_mon),
	try_start_app(dvr),
	try_start_app(hls),
	start_app(amf),
	start_app(erlmedia),
	try_start_app(http_file),
	try_start_app(playlist),
	start_app(mpegts),
  start_app(flussonic),
  ok.

try_start_app(App) ->
  case application:start(App) of
    ok -> start_app(App);
    {error, {already_started, _}} -> start_app(App);
    {error, {"no such file or directory", _}} -> ok
  end.

start_app(App) ->
  case application:start(App) of
    ok -> load_app(App);
    {error, {already_started, _}} -> load_app(App)
  end.

load_app(App) ->
  {ok, Mods} = application:get_key(App, modules),
  [code:load_file(Mod) || Mod <- Mods].


test() ->
  Modules = [
    aac
    ,flv_video_frame
    ,h264
    ,mp4
    % mp4_writer,
    ,packet_codec
    % sdp, 
    ,sdp_encoder
    ,license_client
    ,mpeg2_crc32
    ,mpegts_psi
    ,mpegts_reader
    ,rtmp
    ,rtmp_handshake
    ,rtp
    ,rtp_decoder
    % ,rtsp  % Camera snapshots are required
    ,rtsp_inbound
    ,rtsp_socket
    ,flu_rtmp
    ,mpegts_handler
    ,flu_config
    ,dvr_handler
    ,media_handler
    ,flu_session
    ,flu_file
  ],
  [begin
    io:format("Test: ~p~n", [Module]),
    Module:test()
  end || Module <- Modules],
  ok.

