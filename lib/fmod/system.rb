

module FMOD
  class System < Handle

    CpuUsage = Struct.new(:dsp, :stream, :geometry, :update, :total)

    RamUsage = Struct.new(:current, :max, :total)

    FileUsage = Struct.new(:sample, :stream, :other)

    Speaker = Struct.new(:index, :x, :y, :active)

    Plugin = Struct.new(:handle, :type, :name, :version)

    def initialize(handle)
      super
      @rolloff_callbacks = []
      sig = [TYPE_VOIDP, TYPE_FLOAT]
      abi = FMOD.calling_convention
      cb = Closure::BlockCaller.new(TYPE_FLOAT, sig, abi) do |channel, distance|
        unless @rolloff_callbacks.empty?
          chan = Channel.new(channel)
          @rolloff_callbacks.each { |proc| proc.call(chan, distance) }
        end
        distance
      end
      FMOD.invoke(:System_Set3DRolloffCallback, self, cb)
    end

    def on_rolloff(proc = nil, &block)
      cb = proc || block
      raise LocalJumpError, "No block given."  if cb.nil?
      @rolloff_callbacks << cb
    end

    # @group Speaker Positioning

    ##
    # Helper function to return the speakers as array.
    # @return [Array<Speaker>] the array of speakers.
    def speakers
      each_speaker.to_a
    end

    ##
    # @return [Speaker] the current speaker position for the selected speaker.
    # @see SpeakerIndex
    def speaker(index)
      args = ["\0" * SIZEOF_FLOAT, "\0" * SIZEOF_FLOAT, "\0" * SIZEOF_INT ]
      FMOD.invoke(:System_GetSpeakerPosition, self, index, *args)
      args = [index] + args.join.unpack('ffl')
      args[3] = args[3] != 0
      Speaker.new(*args)
    end

    ##
    # This function allows the user to specify the position of their actual
    # physical speaker to account for non standard setups.
    #
    # It also allows the user to disable speakers from 3D consideration in a
    # game.
    #
    # The function is for describing the "real world" speaker placement to
    # provide a more natural panning solution for 3D sound. Graphical
    # configuration screens in an application could draw icons for speaker
    # placement that the user could position at their will.
    #
    # @overload set_speaker(speaker)
    #   @param speaker [Speaker] The speaker to set.
    # @overload set_speaker(index, x, y, active = true)
    #   @param index [Integer] The index of the speaker to set.
    #     @see SpeakerIndex
    #   @param x [Float] The 2D X position relative to the listener.
    #   @param y [Float] The 2D Y position relative to the listener.
    #   @param active [Boolean] The active state of a speaker.
    # @return [void]
    def set_speaker(*args)
      unless [1, 3, 4].include?(args.size)
        message = "wrong number of arguments: #{args.size} for 1, 3, or 4"
        raise ArgumentError, message
      end
      index, x, y, active = args[0].is_a?(Speaker) ? args[0].values : args
      active = true if args.size == 3
      FMOD.invoke(:System_SetSpeakerPosition, self, index, x, y, active.to_i)
    end

    ##
    # @overload each_speaker
    #   When called with a block, yields each speaker in turn before returning
    #   self.
    #   @yield [speaker] Yields a speaker to the block.
    #   @yieldparam speaker [Speaker] The current enumerated speaker.
    #   @return [self]
    # @overload each_speaker
    #   When called without a block, returns an enumerator for the speakers.
    #   @return [Enumerator]
    def each_speaker
      return to_enum(:each_speaker) unless block_given?
      SpeakerIndex.constants(false).each do |const|
        index = SpeakerIndex.const_get(const)
        yield speaker(index) rescue next
      end
      self
    end

    # @!endgroup

    # @!group Object Creation

    ##
    # @note <b>This must be called to create an {System} object before you can
    #   do anything else.</b>
    #
    # {System} creation function. Use this function to create one, or
    # multiple instances of system objects.
    # @param options [Hash] Options hash.
    # @option options [Integer] :max_channels (32) The maximum number of
    #   channels to be used in FMOD. They are also called "virtual channels" as
    #   you can play as many of these as you want, even if you only have a small
    #   number of software voices.
    # @option options [Integer] :flags (InitFlags::NORMAL) See {InitFlags}. This
    #   can be a selection of flags bitwise OR'ed together to change the
    #   behavior of FMOD at initialization time.
    # @option options [Pointer|String] :driver_data (FMOD::NULL) Driver
    #   specific data that can be passed to the output plugin. For example the
    #   filename for the wav writer plugin.
    # @return [System] the newly created {System} object.
    def self.create(**options)
      max = [options[:max_channels] || 32, 4093].min
      flags = options[:flags] || InitFlags::NORMAL
      driver = options[:driver_data] || FMOD::NULL
      FMOD.invoke(:System_Create, address = "\0" * SIZEOF_INTPTR_T)
      system = new(address)
      FMOD.invoke(:System_Init, system, max, flags, driver)
      system
    end

    ##
    # Loads a sound into memory, or opens it for streaming.
    #
    # @param source [String, Pointer] Name of the file or URL to open encoded in
    #   a UTF-8 string, or a pointer to a pre-loaded sound memory block if
    #   {Mode::OPEN_MEMORY} / {Mode::OPEN_MEMORY_POINT} is used.
    # @param options [Hash] Options hash.
    # @option options [Integer] :mode (Mode::DEFAULT) Behavior modifier for
    #   opening the sound. See {Mode} for explanation of flags.
    # @option options [SoundExInfo] :extra (FMOD::NULL) Extra data which lets
    #   the user provide extended information while playing the sound.
    # @return [Sound] the created sound.
    def create_sound(source, **options)
      mode = options[:mode] || Mode::DEFAULT
      extra = options[:extra] || FMOD::NULL
      sound = int_ptr
      FMOD.invoke(:System_CreateSound, self, source, mode, extra, sound)
      Sound.new(sound)
    end

    ##
    # Opens a sound for streaming. This function is a helper function that is
    # the same as {#create_sound} but has the {Mode::CREATE_STREAM} flag added
    # internally.
    #
    # @param source [String, Pointer] Name of the file or URL to open encoded in
    #   a UTF-8 string, or a pointer to a pre-loaded sound memory block if
    #   {Mode::OPEN_MEMORY} / {Mode::OPEN_MEMORY_POINT} is used.
    # @param options [Hash] Options hash.
    # @option options [Integer] :mode (Mode::DEFAULT) Behavior modifier for
    #   opening the sound. See {Mode} for explanation of flags.
    # @option options [SoundExInfo] :extra (FMOD::NULL) Extra data which lets
    #   the user provide extended information while playing the sound.
    # @return [Sound] the created sound.
    def create_stream(source, **options)
      mode = options[:mode] || Mode::DEFAULT
      extra = options[:extra] || FMOD::NULL
      sound = int_ptr
      FMOD.invoke(:System_CreateSound, self, source, mode, extra, sound)
      Sound.new(sound)
    end

    ##
    # Creates an FMOD defined built in DSP unit object to be inserted into a DSP
    # network, for the purposes of sound filtering or sound generation.
    #
    # This function is used to create special effects that come built into FMOD.
    #
    # @param type [Integer, Class] A pre-defined DSP effect or sound generator
    #   described by in {DspType}, or a Class found within the {Effects} module.
    #
    # @return [Dsp] the created DSP.
    def create_dsp(type)
      unless FMOD.check_type(type, Integer, false)
        unless FMOD.check_type(type, Class) && type < Dsp
          raise TypeError, "#{type} must either be or inherit from #{Dsp}."
        end
      end
      if type.is_a?(Integer)
        klass = Dsp.type_map(type)
      else type.is_a?(Class)
      klass = type
      type = Dsp.type_map(type)
      end
      dsp = int_ptr
      FMOD.invoke(:System_CreateDSPByType, self, type, dsp)
      klass.new(dsp)
    end

    ##
    # Creates a sound group, which can store handles to multiple {Sound}
    # objects.
    # @param name [String] Name of sound group.
    # @return [SoundGroup] the created {SoundGroup}.
    def create_sound_group(name)
      utf8 = name.encode('UTF-8')
      group = int_ptr
      FMOD.invoke(:System_CreateSoundGroup, self, utf8, group)
      SoundGroup.new(group)
    end

    ##
    # Geometry creation function. This function will create a base geometry
    # object which can then have polygons added to it.
    #
    # Polygons can be added to a geometry object using {Geometry.add_polygon}.
    #
    # A geometry object stores its list of polygons in a structure optimized for
    # quick line intersection testing and efficient insertion and updating. The
    # structure works best with regularly shaped polygons with minimal overlap.
    # Many overlapping polygons, or clusters of long thin polygons may not be
    # handled efficiently. Axis aligned polygons are handled most efficiently.
    #
    # The same type of structure is used to optimize line intersection testing
    # with multiple geometry objects.
    #
    # It is important to set the value of max world-size to an appropriate value
    # using {#world_size}. Objects or polygons outside the range of max
    # world-size will not be handled efficiently. Conversely, if max world-size
    # is excessively large, the structure may lose precision and efficiency may
    # drop.
    #
    # @param max_polygons [Integer] Maximum number of polygons within this
    #   object.
    # @param max_vertices [Integer] Maximum number of vertices within this
    #   object.
    def create_geometry(max_polygons, max_vertices)
      geometry = int_ptr
      FMOD.invoke(:System_CreateGeometry, self, max_polygons, max_vertices, geometry)
      Geometry.new(geometry)
    end

    ##
    # Creates a "virtual reverb" object. This object reacts to 3D location and
    # morphs the reverb environment based on how close it is to the reverb
    # object's center.
    #
    # Multiple reverb objects can be created to achieve a multi-reverb
    # environment. 1 Physical reverb object is used for all 3D reverb objects
    # (slot 0 by default).
    #
    # The 3D reverb object is a sphere having 3D attributes (position, minimum
    # distance, maximum distance) and reverb properties. The properties and 3D
    # attributes of all reverb objects collectively determine, along with the
    # listener's position, the settings of and input gains into a single 3D
    # reverb DSP. When the listener is within the sphere of effect of one or
    # more 3D reverbs, the listener's 3D reverb properties are a weighted
    # combination of such 3D reverbs. When the listener is outside all of the
    # reverbs, no reverb is applied.
    #
    # Creating multiple reverb objects does not impact performance. These are
    # "virtual reverbs". There will still be only 1 physical reverb DSP running
    # that just morphs between the different virtual reverbs.
    #
    # @return [Reverb3D] the created {Reverb3D} object.
    def create_reverb
      reverb = int_ptr
      FMOD.invoke(:System_CreateReverb3D, self, reverb)
      Reverb3D.new(reverb)
    end

    ##
    # Creates a {ChannelGroup} object. These objects can be used to assign
    # channels to for group channel settings, such as volume.
    #
    # Channel groups are also used for sub-mixing. Any channels that are
    # assigned to a channel group get sub-mixed into that channel group's DSP.
    #
    # @param name [String, nil] Optional label to give to the channel group for
    #   identification purposes.
    # @return [ChannelGroup] the created {ChannelGroup} object.
    def create_channel_group(name = nil)
      FMOD.invoke(:System_CreateChannelGroup, self, name, group = int_ptr)
      ChannelGroup.new(group)
    end

    ##
    # Creates a {Geometry} object that was previously serialized with
    # {Geometry.save}.
    # @param source [String] Either a filename where object is saved, or a
    #   binary block of serialized data.
    # @param filename [Boolean] +true+ if source is a filename to be loaded,
    #   otherwise +false+ and source will be handled as binary data.
    # @return [Geometry]
    # @see Geometry.save
    def load_geometry(source, filename = true)
      source = IO.open(source, 'rb') { |io| io.read } if filename
      size = source.bytesize
      FMOD.invoke(:System_LoadGeometry, self, source, size, geometry = int_ptr)
      Geometry.new(geometry)
    end

    # @!endgroup

    # @!group System Resources

    ##
    # Retrieves in percent of CPU time - the amount of CPU usage that FMOD is
    # taking for streaming/mixing and {#update} combined.
    #
    # @return [CpuUsage] the current CPU resource usage at the time of the call.
    def cpu_usage
      args = ["\0" * SIZEOF_FLOAT, "\0" * SIZEOF_FLOAT, "\0" * SIZEOF_FLOAT,
        "\0" * SIZEOF_FLOAT, "\0" * SIZEOF_FLOAT]
      FMOD.invoke(:System_GetCPUUsage, self, *args)
      CpuUsage.new(*args.map { |arg| arg.unpack1('f') })
    end

    ##
    # Retrieves the amount of dedicated sound ram available if the platform
    # supports it.
    #
    # Most platforms use main RAM to store audio data, so this function usually
    # isn't necessary.
    #
    # @return [RamUsage] the current RAM resource usage at the time of the call.
    def ram_usage
      args = ["\0" * SIZEOF_INT, "\0" * SIZEOF_INT, "\0" * SIZEOF_INT]
      FMOD.invoke(:System_GetSoundRAM, self, *args)
      RamUsage.new(*args.map { |arg| arg.unpack1('l') })
    end

    ##
    # Retrieves information about file reads by FMOD.
    #
    # The values returned are running totals that never reset.
    #
    # @return [FileUsage] the current total of file read resources used by FMOD
    #   at the time of the call.
    def file_usage
      args = ["\0" * SIZEOF_LONG_LONG, "\0" * SIZEOF_LONG_LONG,
        "\0" * SIZEOF_LONG_LONG]
      FMOD.invoke(:System_GetFileUsage, self, *args)
      FileUsage.new(*args.map { |arg| arg.unpack1('q') })
    end

    # @!endgroup

    # @!group Recording

    ##
    # Stops the recording engine from recording to the specified recording
    # sound.
    #
    # This does +NOT+ raise an error if a the specified driver ID is incorrect
    # or it is not recording.
    #
    # @param driver_id [Integer] Enumerated driver ID.
    #
    # @return [void]
    def stop_recording(driver_id)
      FMOD.invoke(:System_RecordStop, self, driver_id)
    end

    ##
    # Starts the recording engine recording to the specified recording sound.
    #
    # @note The specified sound must be created with {Mode::CREATE_SAMPLE} flag.
    #
    # @param driver_id [Integer] Enumerated driver ID.
    # @param sound [Sound] User created sound for the user to record to.
    # @param loop [Boolean] Flag to tell the recording engine whether to
    #   continue recording to the provided sound from the start again, after it
    #   has reached the end. If this is set to true the data will be continually
    #   be overwritten once every loop.
    #
    # @return [void]
    def record_start(driver_id, sound, loop = false)
      FMOD.check_type(sound, Sound)
      FMOD.invoke(:System_RecordStart, self, driver_id, sound, loop.to_i)
    end

    ##
    # Retrieves the state of the FMOD recording API, ie if it is currently
    # recording or not.
    #
    # @param driver_id [Integer] Enumerated driver ID.
    #
    # @return [Boolean] the current recording state of the specified driver.
    def recording?(driver_id)
      bool = "\0" * SIZEOF_INT
      FMOD.invoke(:System_IsRecording, self, driver_id, bool)
      bool.unpack1('l') != 0
    end

    ##
    # Retrieves the current recording position of the record buffer in PCM
    # samples.
    #
    # @param driver_id [Integer] Enumerated driver ID.
    #
    # @return [Integer] the current recording position in PCM samples.
    def record_position(driver_id)
      position = "\0" * SIZEOF_INT
      FMOD.invoke(:System_GetRecordPosition, self, driver_id, position)
      position.unpack1('L')
    end

    ##
    # Retrieves the number of recording devices available for this output mode.
    #
    # Use this to enumerate all recording devices possible so that the user can
    # select one.
    #
    # @param connected [Boolean]
    #   * *true:* Retrieve the number of recording drivers currently plugged in.
    #   * *false:* Receives the number of recording drivers available for this
    #     output mode.
    #
    # @return [Integer] the number of record drivers.
    def record_driver_count(connected = true)
      total, present = "\0" * SIZEOF_INT, "\0" * SIZEOF_INT
      FMOD.invoke(:System_GetRecordNumDrivers, self, total, present)
      (connected ? present : total).unpack1('l')
    end

    ##
    # Retrieves identification information about a sound device specified by its
    # index, and specific to the output mode set with {#output}.
    #
    # @param id [Integer] Index of the sound driver device. The total number of
    #   devices can be found with {#record_driver_count}.
    #
    # @return [Driver] the specified driver information.
    def record_driver(id)
      args = [id, "\0" * 512, 512, Guid.new] + (0...4).map { "\0" * SIZEOF_INT }
      FMOD.invoke(:System_GetRecordDriverInfo, self, *args)
      Driver.send(:new, args)
    end

    ##
    # @!attribute [r] record_drivers
    # @return [Array<Driver>] the array of available record drivers.
    def record_drivers(connected = true)
      (0...record_driver_count(connected)).map { |i| record_driver(i) }
    end

    # @!endgroup

    # @!group Sound Card Drivers

    ##
    # @!attribute output
    # The output mode for the platform. This is for selecting different OS
    # specific APIs which might have different features.
    #
    # Changing this is only necessary if you want to specifically switch away
    # from the default output mode for the operating system. The most optimal
    # mode is selected by default for the operating system.
    #
    # @see OutputMode
    # @return [Integer] the output mode for the platform.
    integer_reader(:output, :System_GetOutput)
    integer_writer(:output=, :System_SetOutput)

    ##
    # @!attribute [r] driver_count
    # @return [Integer] the number of sound-card devices on the machine,
    #   specific to the output mode set with {#output}.
    integer_reader(:driver_count, :System_GetNumDrivers)

    ##
    # @!attribute current_driver
    # @return [Integer] the currently selected driver number. 0 represents the
    #   primary or default driver.
    integer_reader(:current_driver, :System_GetDriver)
    integer_writer(:current_driver=, :System_SetDriver)

    ##
    # Retrieves identification information about a sound device specified by its
    # index, and specific to the output mode set with {#output}.
    #
    # @param id [Integer] Index of the sound driver device. The total number of
    #   devices can be found with {#driver_count}.
    #
    # @return [Driver] the driver information.
    def driver_info(id)
      args = [id, "\0" * 512, 512, Guid.new] + (0...3).map { "\0" * SIZEOF_INT }
      FMOD.invoke(:System_GetDriverInfo, self, *args)
      Driver.send(:new, args)
    end

    ##
    # @!attribute output_handle
    # Retrieves a pointer to the system level output device module. This means a
    # pointer to a DirectX "LPDIRECTSOUND", or a WINMM handle, or with something
    # like with {OutputType::NO_SOUND} output, the handle will be {FMOD::NULL}.
    #
    # @return [Pointer] the handle to the output mode's native hardware API
    #   object.
    def output_handle
      FMOD.invoke(:System_GetOutputHandle, self, handle = int_ptr)
      Pointer.new(handle.unpack1('J'))
    end

    ##
    # @!attribute [r] drivers
    # @return [Array<Driver>] the array of available drivers.
    def drivers
      (0...driver_count).map { |id| driver_info(id) }
    end

    # @!endgroup

    # @!group 3D Sound

    ##
    # Calculates geometry occlusion between a listener and a sound source.
    #
    # @param listener [Vector] The listener position.
    # @param source [Vector] The source position.
    #
    # @return [Array(Float, Float)] the occlusion values as an array, the first
    #   element being the direct occlusion value, and the second element being
    #   the reverb occlusion value.
    def geometry_occlusion(listener, source)
      FMOD.check_type(listener, Vector)
      FMOD.check_type(source, Vector)
      args = ["\0" * SIZEOF_FLOAT, "\0" * SIZEOF_FLOAT]
      FMOD.invoke(:System_GetGeometryOcclusion, self, listener, source, *args)
      args.join.unpack('ff')
    end

    ##
    # @!attribute listeners
    # The number of 3D "listeners" in the 3D sound scene. This is useful mainly
    # for split-screen game purposes.
    #
    # If the number of listeners is set to more than 1, then panning and doppler
    # are turned off. *All* sound effects will be mono. FMOD uses a "closest
    # sound to the listener" method to determine what should be heard in this
    # case.
    #*  *Minimum:* 1
    # * *Maximum:* {FMOD::MAX_LISTENERS}
    # * *Default:* 1
    # @return [Integer]
    integer_reader(:listeners, :System_Get3DNumListeners)
    integer_writer(:listeners=, :System_Set3DNumListeners, 1, FMOD::MAX_LISTENERS)

    ##
    # @!attribute world_size
    # The maximum world size for the geometry engine for performance / precision
    # reasons
    #
    # This setting should be done first before creating any geometry.
    # It can be done any time afterwards but may be slow in this case.
    #
    # Objects or polygons outside the range of this value will not be handled
    # efficiently. Conversely, if this value is excessively large, the structure
    # may loose precision and efficiency may drop.
    #
    # @return [Float] the maximum world size for the geometry engine.
    float_reader(:world_size, :System_GetGeometrySettings)
    float_writer(:world_size=, :System_SetGeometrySettings)

    # @!endgroup

    # @!group Plugin Support

    ##
    # Loads an FMOD plugin. This could be a DSP, file format or output plugin.
    #
    # @param filename [String] Filename of the plugin to be loaded.
    # @param priority [Integer] Codec plugins only, priority of the codec
    #   compared to other codecs, where 0 is the most important and higher
    #   numbers are less important.
    #
    # @return [Integer] the handle to the plugin.
    def load_plugin(filename, priority = 128)
      # noinspection RubyResolve
      path = filename.encode(Encoding::UTF_8)
      handle = "\0" * SIZEOF_INT
      FMOD.invoke(:System_LoadPlugin, self, path, handle, priority)
      handle.unpack1('L')
    end

    ##
    # Unloads a plugin from memory.
    #
    # @param handle [Integer] Handle to a pre-existing plugin.
    #
    # @return [void]
    def unload_plugin(handle)
      FMOD.invoke(:System_UnloadPlugin, self, handle)
    end

    ##
    # Retrieves the number of available plugins loaded into FMOD at the current
    # time.
    #
    # @param type [Symbol] Determines the type of plugin to factor into the
    #   count.
    # @option type [Symbol] (:all) The following values are valid:
    #   * <b>:all</b> All plugin types.
    #   * <b>:output</b> The plugin type is an output module. FMOD mixed audio
    #     will play through one of these devices
    #   * <b>:codec</b> The plugin type is a file format codec. FMOD will use
    #     these codecs to load file formats for playback.
    #   * <b>:dsp</b> The plugin type is a DSP unit. FMOD will use these plugins
    #     as part of its DSP network to apply effects to output or generate
    #     sound in realtime.
    # @return [Integer] the plugin count.
    def plugin_count(type: :all)
      plugin_type = case type
      when :output then 0
      when :codec then 1
      when :dsp then 2
      else nil
      end
      count = "\0" * SIZEOF_INT
      unless plugin_type.nil?
        FMOD.invoke(:System_GetNumPlugins, self, plugin_type, count)
        return count.unpack1('l')
      end
      total = 0
      (0..2).each do |i|
        FMOD.invoke(:System_GetNumPlugins, self, i, count)
        total += count.unpack1('l')
      end
      total
    end

    ##
    # Specify a base search path for plugins so they can be placed somewhere
    # else than the directory of the main executable.
    #
    # @param directory [String] A string containing a correctly formatted path
    #   to load plugins from.
    #
    # @return [void]
    def plugin_path(directory)
      # noinspection RubyResolve
      path = directory.encode(Encoding::UTF_8)
      FMOD.invoke(:System_SetPluginPath, self, path)
    end

    ##
    # Retrieves the handle of a plugin based on its type and relative index.
    #
    # @param type [Symbol] The type of plugin type.
    #   * <b>:output</b> The plugin type is an output module. FMOD mixed audio
    #     will play through one of these devices
    #   * <b>:codec</b> The plugin type is a file format codec. FMOD will use
    #     these codecs to load file formats for playback.
    #   * <b>:dsp</b> The plugin type is a DSP unit. FMOD will use these plugins
    #     as part of its DSP network to apply effects to output or generate
    #     sound in realtime.
    # @param index [Integer] The relative index for the type of plugin.
    #
    # @return [Integer] the handle to the plugin.
    def plugin(type, index)
      handle = "\0" * SIZEOF_INT
      plugin_type = [:output, :codec, :dsp].index(type)
      raise ArgumentError, "Invalid plugin type: #{type}." if plugin_type.nil?
      FMOD.invoke(:System_GetPluginHandle, self, plugin_type, index, handle)
      handle.unpack1('L')
    end

    ##
    # Returns nested plugin definition for the given index.
    #
    # For plugins consisting of a single definition, only index 0 is valid and
    # the returned handle is the same as the handle passed in.
    #
    # @param handle [Integer] A handle to an existing plugin returned from
    #   {#load_plugin}.
    # @param index [Integer] Index into the list of plugin definitions.
    #
    # @return [Integer] the handle to the nested plugin.
    def nested_plugin(handle, index)
      nested = "\0" * SIZEOF_INT
      FMOD.invoke(:System_GetNestedPlugin, self, handle, index, nested)
      nested.unpack1('L')
    end

    ##
    # Returns the number of plugins nested in the one plugin file.
    #
    # Plugins normally have a single definition in them, in which case the count
    # is always 1.
    #
    # For plugins that have a list of definitions, this function returns the
    # number of plugins that have been defined. {#nested_plugin} can be used to
    # find each handle.
    #
    # @param handle [Integer] A handle to an existing plugin returned from
    #   {#load_plugin}.
    #
    # @return [Integer] the number of nested plugins.
    def nested_plugin_count(handle)
      count = "\0" * SIZEOF_INT
      FMOD.invoke(:System_GetNumNestedPlugins, self, handle, count)
      count.unpack1('l')
    end

    ##
    # Retrieves information to display for the selected plugin.
    #
    # @param handle [Integer] The handle to the plugin.
    #
    # @return [Plugin] the plugin information.
    def plugin_info(handle)
      name, type, vs = "\0" * 512, "\0" * SIZEOF_INT, "\0" * SIZEOF_INT
      FMOD.invoke(:System_GetPluginInfo, self, handle, type, name, 512, vs)
      type = [:output, :codec, :dsp][type]
      # noinspection RubyResolve
      name = name.delete("\0").force_encoding(Encoding::UTF_8)
      vs = "%08X" % vs.unpack1('L')
      Plugin.new(handle, type, name, "#{vs[0, 4].to_i}.#{vs[4, 4].to_i}")
    end

    ##
    # @!attribute plugin_output
    # @return [Integer] the currently selected output as an ID in the list of
    #   output plugins.
    integer_reader(:plugin_output, :System_GetOutputByPlugin)
    integer_writer(:plugin_output=, :System_SetOutputByPlugin)

    ##
    # @param handle [Integer] Handle to a pre-existing DSP plugin.
    # @return [DspDescription] the description structure for a pre-existing DSP
    #   plugin.
    def plugin_dsp_info(handle)
      FMOD.invoke(:System_GetDSPInfoByPlugin, self, handle, address = int_ptr)
      DspDescription.new(address)
    end

    ##
    # Enumerates the loaded plugins, optionally specifying the type of plugins
    # to loop through.
    #
    # @overload each_plugin(plugin_type = :all)
    #   When a block is passed, yields each plugin to the block in turn before
    #   returning self.
    #   @yield [plugin] Yields a plugin to the block.
    #   @yieldparam plugin [Plugin] The currently enumerated plugin.
    #   @return [self]
    # @overload each_plugin(plugin_type = :all)
    #   When no block is given, returns an enumerator for the plugins.
    #   @return [Enumerator]
    # @param plugin_type [Symbol] Specifies the type of plugin(s) to enumerate.
    #   * <b>:output</b> The plugin type is an output module. FMOD mixed audio
    #     will play through one of these devices
    #   * <b>:codec</b> The plugin type is a file format codec. FMOD will use
    #     these codecs to load file formats for playback.
    #   * <b>:dsp</b> The plugin type is a DSP unit. FMOD will use these plugins
    #     as part of its DSP network to apply effects to output or generate
    #     sound in realtime.
    def each_plugin(plugin_type = :all)
      return to_enum(:each_plugin) unless block_given?
      types = plugin_type == :all ? [:output, :codec, :dsp] : [plugin_type]
      types.each do |type|
        (0...plugin_count(type)).each do |index|
          handle = plugin(type, index)
          yield plugin_info(handle)
        end
      end
      self
    end

    # @!endgroup





































    def network_proxy
      buffer = "\0" * 512
      FMOD.invoke(:System_GetNetworkProxy, self, buffer, 512)
      # noinspection RubyResolve
      buffer.delete("\0").force_encoding(Encoding::UTF_8)
    end

    def network_proxy=(url)
      # noinspection RubyResolve
      FMOD.invoke(:System_SetNetworkProxy, self, url.encode(Encoding::UTF_8))
    end

    integer_reader(:network_timeout, :System_GetNetworkTimeout)
    integer_writer(:network_timeout=, :System_SetNetworkTimeout)

    integer_reader(:software_channels, :System_GetSoftwareChannels)
    integer_writer(:software_channels=, :System_SetSoftwareChannels, 0, 64)



    def master_channel_group
      FMOD.invoke(:System_GetMasterChannelGroup, self, group = int_ptr)
      ChannelGroup.new(group)
    end

    def master_sound_group
      FMOD.invoke(:System_GetMasterSoundGroup, self, group = int_ptr)
      SoundGroup.new(group)
    end


    def update
      FMOD.invoke(:System_Update, self)
    end

    ##
    # Closes the {System} object without freeing the object's memory, so the
    # system handle will still be valid.
    #
    # Closing the output renders objects created with this system object
    # invalid. Make sure any sounds, channel groups, geometry and DSP objects
    # are released before closing the system object.
    #
    # @return [void]
    def close
      FMOD.invoke(:System_Close, self)
    end

    ##
    # Returns the current version of FMOD being used.
    #
    # @return [String]
    def version
      FMOD.invoke(:System_GetVersion, self, version = "\0" * SIZEOF_INT)
      version = version.unpack1('L').to_s(16).rjust(8, '0')
      major = version[0, 4].to_i
      minor = version[4, 2].to_i
      build = version[6, 2].to_i
      "#{major}.#{minor}.#{build}"
    end

    ##
    # Plays a sound object on a particular channel and {ChannelGroup}.
    #
    # When a sound is played, it will use the sound's default frequency and
    # priority.
    #
    # A sound defined as {Mode::THREE_D} will by default play at the position of
    # the listener.
    #
    # Channels are reference counted. If a channel is stolen by the FMOD
    # priority system, then the handle to the stolen voice becomes invalid, and
    # Channel based commands will not affect the new sound playing in its place.
    # If all channels are currently full playing a sound, FMOD will steal a
    # channel with the lowest priority sound. If more channels are playing than
    # are currently available on the sound-card/sound device or software mixer,
    # then FMOD will "virtualize" the channel. This type of channel is not
    # heard, but it is updated as if it was playing. When its priority becomes
    # high enough or another sound stops that was using a real hardware/software
    # channel, it will start playing from where it should be. This technique
    # saves CPU time (thousands of sounds can be played at once without actually
    # being mixed or taking up resources), and also removes the need for the
    # user to manage voices themselves. An example of virtual channel usage is a
    # dungeon with 100 torches burning, all with a looping crackling sound, but
    # with a sound-card that only supports 32 hardware voices. If the 3D
    # positions and priorities for each torch are set correctly, FMOD will play
    # all 100 sounds without any 'out of channels' errors, and swap the real
    # voices in and out according to which torches are closest in 3D space.
    # Priority for virtual channels can be changed in the sound's defaults, or
    # at runtime with {Channel.priority}.
    #
    # @param sound [Sound] The sound to play.
    # @param group [ChannelGroup] The {ChannelGroup} become a member of. This is
    #   more efficient than using {Channel.group}, as it does it during the
    #   channel setup, rather than connecting to the master channel group, then
    #   later disconnecting and connecting to the new {ChannelGroup} when
    #   specified. Specify +nil+ to ignore (use master {ChannelGroup}).
    # @param paused [Boolean] flag to specify whether to start the channel
    #   paused or not. Starting a channel paused allows the user to alter its
    #   attributes without it being audible, and un-pausing with
    #   ChannelControl.resume actually starts the sound.
    #
    # @return [Channel] the newly playing channel.
    def play_sound(sound, group = nil, paused = false)
      FMOD.check_type(sound, Sound)
      channel = int_ptr
      paused = paused.to_i
      FMOD.invoke(:System_PlaySound, self, sound, group, paused, channel)
      Channel.new(channel)
    end

    def [](index)
      reverb = int_ptr
      FMOD.invoke(:System_GetReverbProperties, self, index, reverb)
      Reverb.new(reverb.unpack1('J'))
    end

    def []=(index, reverb)
      FMOD.check_type(reverb, Reverb)
      FMOD.invoke(:System_SetReverbProperties, self, index, reverb)
    end

    def mixer_suspend
      FMOD.invoke(:System_MixerSuspend, self)
      if block_given?
        yield
        FMOD.invoke(:System_MixerResume, self)
      end
    end

    def mixer_resume
      FMOD.invoke(:System_MixerResume, self)
    end

    ##
    # Mutual exclusion function to lock the FMOD DSP engine (which runs
    # asynchronously in another thread), so that it will not execute. If the
    # FMOD DSP engine is already executing, this function will block until it
    # has completed.
    #
    # The function may be used to synchronize DSP network operations carried out
    # by the user.
    #
    # An example of using this function may be for when the user wants to
    # construct a DSP sub-network, without the DSP engine executing in the
    # background while the sub-network is still under construction.
    #
    # Once the user no longer needs the DSP engine locked, it must be unlocked
    # with {#unlock_dsp}.
    #
    # Note that the DSP engine should not be locked for a significant amount of
    # time, otherwise inconsistency in the audio output may result. (audio
    # skipping/stuttering).
    #
    # @overload lock_dsp
    #   Locks the DSP engine, must unlock with {#unlock_dsp}.
    # @overload lock_dsp
    #   @yield Locks the DSP engine, and unlocks it when the block exits.
    # @return [void]
    def lock_dsp
      FMOD.invoke(:System_LockDSP, self)
      if block_given?
        yield
        FMOD.invoke(:System_UnlockDSP, self)
      end
    end

    ##
    # Mutual exclusion function to unlock the FMOD DSP engine (which runs
    # asynchronously in another thread) and let it continue executing.
    #
    # @note The DSP engine must be locked with {#lock_dsp} before this function
    # is called.
    # @return [void]
    def unlock_dsp
      FMOD.invoke(:System_UnlockDSP, self)
    end

    ##
    # Helper method to create and enumerate each type of internal DSP unit.
    # @overload each_dsp
    #   When called with a block, yields each DSP type in turn before returning
    #   self.
    #   @yield [dsp] Yields a DSP unit to the block.
    #   @yieldparam dsp [Dsp] The current enumerated DSP unit.
    #   @return [self]
    # @overload each_dsp
    #   When called without a block, returns an enumerator for the DSP units.
    #   @return [Enumerator]
    def each_dsp
      return to_enum(:each_dsp) unless block_given?
      FMOD::DspType.constants(false).each do |const|
        type = DspType.const_get(const)
        yield create_dsp(type) rescue next
      end
      self
    end

    ##
    # Retrieves the number of currently playing channels.
    # @param total [Boolean] +true+ to return the number of playing channels
    #   (both real and virtual), +false+ to return the number of playing
    #   non-virtual channels only.
    # @return [Integer] the number of playing channels.
    def playing_channels(total = true)
      count, real = "\0" * SIZEOF_INT, "\0" * SIZEOF_INT
      FMOD.invoke(:System_GetChannelsPlaying, self, count, real)
      (total ? count : real).unpack1('l')
    end

    ##
    # Retrieves a handle to a channel by ID.
    #
    # @param id [Integer] Index in the FMOD channel pool. Specify a channel
    #   number from 0 to the maximum number of channels specified in {#create}
    #   minus 1.
    #
    # @return [Channel] the requested channel.
    def channel(id)
      FMOD.invoke(:System_GetChannel, self, id, handle = int_ptr)
      Channel.new(handle)
    end

  end
end


