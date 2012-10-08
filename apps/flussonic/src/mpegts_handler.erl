%%% @author     Max Lapshin <max@maxidoors.ru> [http://erlyvideo.org]
%%% @copyright  2010-2012 Max Lapshin
%%% @doc        mpegts handler
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
-module(mpegts_handler).
-author('Max Lapshin <max@maxidoors.ru>').

-export([init/3, handle/2, terminate/2]).
-export([read_loop/4]).
-export([write_loop/4]).


-include_lib("cowboy/include/http.hrl").
-include_lib("erlmedia/include/video_frame.hrl").
-include("log.hrl").
-include_lib("eunit/include/eunit.hrl").


-record(mpegts, {
  pid,
  name,
  options,
  method
}).

init({_Any,http}, Req, Opts) ->
  {PathInfo, Req1} = cowboy_http_req:path_info(Req),
  Name = flu:join(PathInfo, "/"),
  {Method, Req2} = cowboy_http_req:method(Req1),
  {ok, Req2, #mpegts{name = Name, method = Method, options = Opts}}.

handle(Req, State) ->
  try handle0(Req, State) of
    Reply -> Reply
  catch
    throw:{return,Code,Text} ->
      {ok, R1} = cowboy_http_req:reply(Code, [], Text, Req),
      {ok, R1, undefined}
  end.


handle0(Req, #mpegts{name = RawName, options = Options, method = 'GET'} = State) ->
  Socket = Req#http_req.socket,
  Transport = Req#http_req.transport,
  
  Name = media_handler:check_sessions(Req, RawName, Options),

  {ok, Pid} = case flu_stream:autostart(Name, Options) of
     {ok, P} -> {ok, P};
     _ -> throw({return, 404, "No stream found\n"})
  end,
  Mpegts = mpegts:init([{resync_on_keyframe,true}]),
  flu_stream:subscribe(Pid, Options),
  ?D({mpegts_play,Name}),
  Transport:send(Socket, "HTTP/1.0 200 OK\r\nContent-Type: video/mpeg2\r\nConnection: close\r\n\r\n"),
  case (catch write_loop(Socket, Transport, Mpegts, false)) of
    {'EXIT', Error} -> ?D({exit,Error,erlang:get_stacktrace()});
    ok -> ok;
    _Else -> ?D(_Else)
  end,
  ?D({mpegts_play,Name,stop}),
  {ok, Req, State};

handle0(Req, #mpegts{name = StreamName, options = Options, method = 'PUT'} = State) ->
  Socket = Req#http_req.socket,
  Transport = Req#http_req.transport,
  
  ?D({mpegts_input,StreamName}),
  
  {ok, Recorder} = flu_stream:autostart(StreamName, Options),
  {ok, Reader} = mpegts_reader:init([]),
  
  ?MODULE:read_loop(Recorder, Reader, Transport, Socket),
  ?D({exit,mpegts_reader}),
  {ok, Req, State}.


terminate(_,_) -> ok.

  
  
read_loop(Recorder, Reader, Transport, Socket) ->
  case Transport:recv(Socket, 16*1024, 10000) of
    {ok, Bin} ->
      {ok, Reader1, Frames} = mpegts_reader:decode(Bin, Reader),
      [Recorder ! Frame || Frame <- Frames],
      ?MODULE:read_loop(Recorder, Reader1, Transport, Socket);
    Else ->
      Else
  end.

    

write_loop(Socket, Transport, Mpegts, Started) ->
  receive
    #video_frame{flavor = config} = F ->
      % ?D({F#video_frame.flavor, F#video_frame.codec, round(F#video_frame.dts)}),
      {Mpegts1, <<>>} = mpegts:encode(Mpegts, F),
      ?MODULE:write_loop(Socket, Transport, Mpegts1, Started);
    #video_frame{flavor = keyframe} = F when Started == false ->
      % ?D({F#video_frame.flavor, F#video_frame.codec, round(F#video_frame.dts)}),
      {Mpegts1, Data} = mpegts:encode(Mpegts, F),
      ok = Transport:send(Socket, Data),
      ?MODULE:write_loop(Socket, Transport, Mpegts1, true);
    #video_frame{} when Started == false ->
      ?MODULE:write_loop(Socket, Transport, Mpegts, Started);    
    #video_frame{} = F ->
      % ?D({F#video_frame.flavor, F#video_frame.codec, round(F#video_frame.dts)}),
      case mpegts:encode(Mpegts, F) of
        {Mpegts1, <<>>} ->
          ?MODULE:write_loop(Socket, Transport, Mpegts1, Started);
        {Mpegts1, Data} ->
          case Transport:send(Socket, Data) of
            ok -> ?MODULE:write_loop(Socket, Transport, Mpegts1, Started);
            Else -> Else
          end
      end;
    {'DOWN', _, _, _, _} ->
      ok;
    Message ->
      ?D(Message)
  after
    20000 ->
      timeout
  end.
  

mpegts_test_() ->
  {foreach,
  fun() ->
      Modules = [flu_config],
      meck:new(Modules, [{passthrough,true}]),
      Config = [{mpegts, <<"mpegts">>, []}],
      meck:expect(flu_config, get_config, fun() -> Config end),
      lager:set_loglevel(lager_console_backend, notice),
      cowboy:start_listener(fake_http, 3, 
        cowboy_tcp_transport, [{port,5555}],
        cowboy_http_protocol, [{dispatch,[{'_',flu_config:parse_routes(Config)}]}]
      ), 

      Modules
  end,
  fun(Modules) ->
    cowboy:stop_listener(fake_http),
    lager:set_loglevel(lager_console_backend, info),
    meck:unload(Modules) 
  end,
  [
    fun test_mpegts/0
  ]
  }.

test_mpegts() ->
  {ok, Stream} = flu_stream:autostart(<<"testlivestream">>, [{source_timeout,10000},{source,self()}]),
  Stream ! flu_rtmp_tests:h264_aac_media_info(),
  {ok, Sock} = gen_tcp:connect("127.0.0.1", 5555, [binary,{packet,http},{active,false}]),
  gen_tcp:send(Sock, "GET /mpegts/testlivestream HTTP/1.0\r\n\r\n"),
  {ok, {http_response, _, Code,_}} = gen_tcp:recv(Sock, 0),
  read_headers(Sock),
  ?assertEqual(200, Code),
  [Stream ! Frame || Frame <- flu_rtmp_tests:h264_aac_frames()],
  Data = read_stream(Sock),
  gen_tcp:close(Sock),
  flussonic_sup:stop_stream(<<"testlivestream">>),
  ?assert(size(Data) > 0),
  ?assert(size(Data) > 100),
  {ok, Frames} = mpegts_decoder:decode_file(Data),
  ?assert(length(Frames) > 10),
  ok.


read_headers(Sock) ->
  case gen_tcp:recv(Sock, 0) of
    {ok, {http_header, _, _, _, _}} -> read_headers(Sock);
    {ok, http_eoh} -> inet:setopts(Sock, [binary,{packet,raw}]), ok
  end.

read_stream(Sock) -> read_stream(Sock, []).


read_stream(Sock, Acc) ->
  case gen_tcp:recv(Sock, 188, 500) of
    {ok, Data} -> read_stream(Sock, [Data|Acc]);
    {error, _} -> iolist_to_binary(lists:reverse(Acc))
  end.

