-module(flu_rtmp_tests).
-include_lib("rtmp/include/rtmp.hrl").
-include_lib("erlmedia/include/video_frame.hrl").
-include_lib("erlmedia/include/media_info.hrl").
-include_lib("eunit/include/eunit.hrl").

-compile(export_all).

-define(S, {stereo, bit16, rate44}).

-record(env, {
  rtmp,
  stream,
  name,
  env
}).

h264_config() ->
  Body = <<1,66,192,21,253,225,0,23,103,66,192,21,146,68,15,4,127,88,8,128,0,1,244,0,0,97,161,71,139,23,80,1,0,4,104,206,50,200>>,
  #video_frame{content = video, codec = h264, flavor = config, track_id = 100, dts = 0, pts = 0, body = Body}.

aac_config() ->
  #video_frame{content = audio, codec = aac, flavor = config, track_id = 101, dts = 0, pts = 0, body = <<17,144>>, sound = ?S}.

mp3_frame(DTS) ->
  Body = <<255,243,96,192,88,25,185,54,65,108,98,70,144,79,60,68,175,98,168,136,90,227,131,22,229,33,196,150,106,173,87,234,
  183,134,115,54,144,195,76,253,120,92,98,101,80,198,219,49,177,8,48,201,133,91,67,134,158,251,67,143,147,252,165,147,93,218,
  115,120,209,73,233,205,170,35,181,225,226,245,242,76,127,226,238,230,91,188,55,201,203,126,116,145,201,172,68,170,72,136,
  10,164,55,1,135,133,168,38,24,54,86,182,159,66,15,60,54,72,99,146,116,64,57,225,13,98,198,92,137,25,39,138,227,6,179,90,39,
  238,99,169,233,108,194,204,56,234,215,204,0,105,165,91,226,183,97,36,40,145>>,
  #video_frame{content = audio, codec = mp3, flavor = frame, dts = DTS, pts = DTS, body = Body, sound = ?S}.

setup_publish() ->
  setup_publish([]).

setup_publish(Options) ->
  Env = flu_config:get_config(),
  lager:set_loglevel(lager_console_backend, notice),
  Auth = case proplists:get_value(auth, Options) of
    undefined -> 
      Env1 = lists:keydelete(publish_password, 1, Env),
      application:set_env(flussonic, config, Env1),
      <<>>;
    A ->
      [Login,Password] = string:tokens(A, ":"),
      Env1 = lists:keystore(publish_password, 1, Env, {publish_password, A}),
      application:set_env(flussonic, config, Env1),
      <<"?login=", (list_to_binary(Login))/binary, "&password=", (list_to_binary(Password))/binary>>
  end,
  StreamName = iolist_to_binary([<<"testlivecam">>, integer_to_list(random:uniform(100))]),

  flussonic_sup:stop_stream(StreamName),
  {ok, RTMP} = rtmp_lib:connect("rtmp://localhost/live"),
  Stream = rtmp_lib:createStream(RTMP),
  rtmp_lib:publish(RTMP, Stream, <<StreamName/binary, Auth/binary>>),
  #env{rtmp = RTMP, stream=Stream, name = StreamName, env=Env}.

teardown_publish(#env{rtmp=RTMP, name = StreamName, env=Env}) ->
  rtmp_socket:close(RTMP),
  flussonic_sup:stop_stream(StreamName),
  application:set_env(flussonic, config, Env),
  lager:set_loglevel(lager_console_backend, info),
  ok.


flu_rtmp_test_() ->
  {foreach, 
  fun setup_publish/0,
  fun teardown_publish/1,
  [ {with, [fun(R) -> publish(h264_aac, R) end]},
    {with, [fun(R) -> publish(h264_mp3, R) end]}
  ]}.

publish_with_password_test_() ->
  {setup,
  fun() -> setup_publish([{auth, "l0gin:passw"}]) end,
  fun teardown_publish/1,
  {with,[
    fun(R) -> publish(h264_aac, R) end
  ]}}.
  

h264_aac_frames() ->
[
  h264_config(),
  aac_config()
] ++ video_frame:sort([
  #video_frame{content = video,track_id=100, codec = h264, flavor = keyframe, dts = 0, pts = 0, body = <<"keyframe">>},
  #video_frame{content = video,track_id=100, codec = h264, flavor = frame, dts = 40, pts = 40, body = <<"frame">>},
  #video_frame{content = video,track_id=100, codec = h264, flavor = frame, dts = 80, pts = 80, body = <<"frame">>},
  #video_frame{content = video,track_id=100, codec = h264, flavor = frame, dts = 120, pts = 120, body = <<"frame">>},
  #video_frame{content = video,track_id=100, codec = h264, flavor = frame, dts = 160, pts = 160, body = <<"frame">>},
  #video_frame{content = video,track_id=100, codec = h264, flavor = frame, dts = 200, pts = 200, body = <<"frame">>},
  #video_frame{content = video,track_id=100, codec = h264, flavor = frame, dts = 240, pts = 240, body = <<"frame">>},
  #video_frame{content = video,track_id=100, codec = h264, flavor = frame, dts = 280, pts = 280, body = <<"frame">>},
  #video_frame{content = video,track_id=100, codec = h264, flavor = frame, dts = 320, pts = 320, body = <<"frame">>},

  #video_frame{content = audio,track_id=101, codec = aac, flavor = frame, dts = 0, pts = 0, body = <<"aac">>, sound = ?S},
  #video_frame{content = audio,track_id=101, codec = aac, flavor = frame, dts = 23, pts = 23, body = <<"aac">>, sound = ?S},
  #video_frame{content = audio,track_id=101, codec = aac, flavor = frame, dts = 46, pts = 46, body = <<"aac">>, sound = ?S},
  #video_frame{content = audio,track_id=101, codec = aac, flavor = frame, dts = 69, pts = 69, body = <<"aac">>, sound = ?S},
  #video_frame{content = audio,track_id=101, codec = aac, flavor = frame, dts = 92, pts = 92, body = <<"aac">>, sound = ?S},
  #video_frame{content = audio,track_id=101, codec = aac, flavor = frame, dts = 115, pts = 115, body = <<"aac">>, sound = ?S},
  #video_frame{content = audio,track_id=101, codec = aac, flavor = frame, dts = 139, pts = 139, body = <<"aac">>, sound = ?S},
  #video_frame{content = audio,track_id=101, codec = aac, flavor = frame, dts = 162, pts = 162, body = <<"aac">>, sound = ?S},
  #video_frame{content = audio,track_id=101, codec = aac, flavor = frame, dts = 185, pts = 185, body = <<"aac">>, sound = ?S}
]).


h264_aac_media_info() ->
  MI1 = video_frame:define_media_info(#media_info{flow_type = stream}, h264_config()),
  MI2 = video_frame:define_media_info(MI1, aac_config()),
  MI2.

publish(h264_aac, #env{rtmp= RTMP, name = StreamName, stream=Stream}) ->
  [rtmp_publish:send_frame(RTMP, Stream, Frame) || Frame <- h264_aac_frames()],
  
  timer:sleep(300),
  
  MediaInfo = flu_stream:media_info(StreamName),
  ?assertMatch(#media_info{streams = [#stream_info{codec = h264}, #stream_info{codec = aac}]}, MediaInfo),
  ok;

publish(h264_mp3, #env{rtmp= RTMP, name = StreamName, stream=Stream}) ->
  rtmp_publish:send_frame(RTMP, Stream, h264_config()),

  rtmp_publish:send_frame(RTMP, Stream, #video_frame{content = video, codec = h264, flavor = keyframe, dts = 0, pts = 0, body = <<"keyframe">>}),
  rtmp_publish:send_frame(RTMP, Stream, mp3_frame(0)),
  rtmp_publish:send_frame(RTMP, Stream, mp3_frame(23)),
  rtmp_publish:send_frame(RTMP, Stream, #video_frame{content = video, codec = h264, flavor = frame, dts = 40, pts = 40, body = <<"frame">>}),
  rtmp_publish:send_frame(RTMP, Stream, mp3_frame(46)),
  rtmp_publish:send_frame(RTMP, Stream, #video_frame{content = video, codec = h264, flavor = frame, dts = 80, pts = 80, body = <<"frame">>}),
  rtmp_publish:send_frame(RTMP, Stream, mp3_frame(69)),
  rtmp_publish:send_frame(RTMP, Stream, mp3_frame(92)),
  rtmp_publish:send_frame(RTMP, Stream, #video_frame{content = video, codec = h264, flavor = frame, dts = 120, pts = 120, body = <<"frame">>}),
 
  timer:sleep(300),

  MediaInfo = flu_stream:media_info(StreamName),
  ?assertMatch(#media_info{streams = [#stream_info{codec = h264}, #stream_info{codec = mp3}]}, MediaInfo),
  ok.


  
run(Suite) ->
  try run0(Suite) of
    R -> R
  catch
    Class:Error -> 
      ?debugFmt("~s:~p ~240p~n", [Class, Error, erlang:get_stacktrace()])
  end.

run0(Suite) ->
  R = setup_publish(),
  publish(Suite, R),
  teardown_publish(R).


play_rejected_test_() ->
  {foreach, fun() ->
    meck:new([flu_config], [{passthrough,true}]),
    lager:set_loglevel(lager_console_backend, notice),
    [flu_config]
  end,
  fun(Modules) ->
    lager:set_loglevel(lager_console_backend, info),
    meck:unload(Modules) 
  end,
  [
    fun test_forbidden_password/0
  ]}.

test_forbidden_password() ->
  meck:expect(flu_config, get_config, fun() -> [{sessions, "http://127.0.0.5/"}] end),
  ?assertThrow({rtmp_error,{play,<<"ort">>}},rtmp_lib:play("rtmp://127.0.0.1/live/ort", [{timeout,500}])),
  ok.





rtmp_session_test_() ->
  {foreach, 
  fun() ->
    Modules = [fake_rtmp, flu_config],
    meck:new(Modules, [{passthrough,true}]),
    meck:expect(fake_rtmp, create_client, fun(Socket) ->
      {ok, Sess} = supervisor:start_child(rtmp_session_sup, [fake_rtmp]),
      rtmp_session:set_socket(Sess, Socket),
      {ok, Sess}
    end),
    meck:expect(fake_rtmp, init, fun(Session) -> {ok, Session} end),
    meck:expect(fake_rtmp, handle_control, fun(_Msg, Session) -> {ok, Session} end),
    meck:expect(fake_rtmp, handle_rtmp_call, fun(Session, #rtmp_funcall{command = Command} = AMF) ->
      fake_rtmp:Command(Session, AMF)
    end),
    meck:expect(fake_rtmp, connect, fun(Session, AMF) -> {unhandled, Session, AMF} end),
    meck:expect(fake_rtmp, createStream, fun(Session, AMF) -> {unhandled, Session, AMF} end),
    {ok, RTMP} = rtmp_listener:start_link(5556,fake_rtmp,fake_rtmp,[]),
    unlink(RTMP),
    {RTMP, Modules}
  end,
  fun({RTMP, Modules}) ->
    erlang:exit(RTMP, shutdown),
    timer:sleep(50),
    meck:unload(Modules)
  end,
  [
    fun test_publish_catch_dvr/0
  ]}.



test_publish_catch_dvr() ->
  meck:expect(flu_config, get_config, fun() -> [{live, <<"livedvr">>, [{dvr, "movies"}]}] end),
  Self = self(),
  meck:expect(fake_rtmp, publish, fun(Session, #rtmp_funcall{stream_id = StreamId, args = [null, Name|_]} = AMF) ->
    Socket = rtmp_session:get(Session, socket),
    rtmp_lib:notify_publish_start(Socket, StreamId, 0, Name),
    Self ! {publish, Session, AMF},
    Session 
  end),
  {ok, RTMP} = rtmp_lib:connect("rtmp://localhost:5556/livedvr"),
  Stream = rtmp_lib:createStream(RTMP),
  rtmp_lib:publish(RTMP, Stream, <<"stream0">>),
  receive
    {publish, Session, _AMF} ->
      ?assertEqual([{dvr,"movies"}], flu_rtmp:publish_options(Session))
  after
    1000 -> ?assert(false)
  end,
  erlang:exit(RTMP, shutdown),
  ok.


























  