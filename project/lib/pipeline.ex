defmodule Membrane.Demo.CompositorExample do
  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.RTMP
  alias Membrane.H264
  alias Membrane.LiveCompositor
  alias Membrane.HTTPAdaptiveStream

  # Range of ports that will be used for communication between LiveCompositor server and Membrane pipeline
  @private_port_range {7000, 8000}
  @video_output_id "video_output"

  @impl true
  def handle_init(_context, _opts) do
    {:ok, rtmp_pid} =
      Membrane.RTMP.Server.start_link(%{
        handler: %RTMP.Source.ClientHandler{controlling_process: self()},
        port: 9000,
        use_ssl?: false
      })

    structure = [
      child(:live_compositor, %LiveCompositor{
        framerate: {30, 1},

        # You can define on what port or in what port range LiveCompositor should be started.
        # Communication between Membrane pipeline and the compositor instance will happen 
        # only on the localhost, so this port should not be exposed publicly.
        api_port: @private_port_range

        # To use custom compositor server
        # server_setup: {:start_locally, System.get_env("LIVE_COMPOSITOR_PATH")}
      }),
      child(:sink, %HTTPAdaptiveStream.SinkBin{
        manifest_module: HTTPAdaptiveStream.HLS,
        target_window_duration: :infinity,
        persist?: false,
        storage: %HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }),
      get_child(:live_compositor)
      |> via_out(Pad.ref(:video_output, @video_output_id),
        options: [
          encoder: %LiveCompositor.Encoder.FFmpegH264{
            preset: :ultrafast
          },
          port: @private_port_range,
          width: 1280,
          height: 720,
          initial: %{root: scene([])}
        ]
      )
      |> via_in(Pad.ref(:input, :video),
        options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)]
      )
      |> get_child(:sink)
    ]

    {[spec: structure], %{rtmp_pid: rtmp_pid, input_ids: []}}
  end

  @impl true
  def handle_setup(_ctx, state) do
    {[], state}
  end

  @impl true
  def handle_info({:client_connected, app, stream_key}, _ctx, state) do
    RTMP.Server.subscribe(state.rtmp_pid, app, stream_key)
    {[], state}
  end

  @impl true
  def handle_info({:client_ref, client_ref, app, stream_key}, _ctx, state) do
    input_id = "#{app}/#{stream_key}"

    if Enum.member?(state.input_ids, input_id) do
      {[], state}
    else
      links = [
        child({:src, client_ref}, %RTMP.SourceBin{
          client_ref: client_ref
        })
        |> via_out(:video)
        |> child({:input_parser, input_id}, %H264.Parser{
          output_alignment: :nalu,
          output_stream_structure: :annexb,
          generate_best_effort_timestamps: %{framerate: {30, 1}}
        })
        |> via_in(Pad.ref(:video_input, input_id),
          options: [port: @private_port_range, required: true]
        )
        |> get_child(:live_compositor),
        get_child({:src, client_ref})
        |> via_out(:audio)
        |> child(Membrane.Debug.Sink)
      ]

      spec = {links, group: "input_group_#{input_id}"}
      state = %{state | input_ids: [input_id | state.input_ids]}

      scene_update =
        %LiveCompositor.Request.UpdateVideoOutput{
          output_id: @video_output_id,
          root: scene(state.input_ids)
        }

      {[
         spec: spec,
         notify_child: {:live_compositor, scene_update}
       ], state}
    end
  end

  @impl true
  def handle_child_notification(
        {:input_eos, Pad.ref(:video_input, pad_id), ctx},
        :live_compositor,
        _membrane_ctx,
        state
      ) do
    input_ids = Enum.filter(state.input_ids, fn id -> id != pad_id end)
    state = %{state | input_ids: input_ids}

    scene_update =
      %LiveCompositor.Request.UpdateVideoOutput{
        output_id: @video_output_id,
        root: scene(state.input_ids)
      }

    {[
       remove_children: "input_group_#{pad_id}",
       notify_child: {:live_compositor, scene_update}
     ], state}
  end

  @impl true
  def handle_child_notification(_notification, _child, _ctx, state) do
    {[], state}
  end

  @spec scene(list(LiveCompositor.input_id())) :: map()
  defp scene(input_ids) do
    %{
      type: :tiles,
      padding: 10,
      children:
        input_ids |> Enum.map(fn input_id -> %{type: :input_stream, input_id: input_id} end)
    }
  end
end
