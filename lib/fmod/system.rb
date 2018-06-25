

module FMOD
  class System < Handle

    CpuUsage = Struct.new(:dsp, :stream, :geometry, :update, :total)

    RamUsage = Struct.new(:current, :max, :total)

    FileUsage = Struct.new(:sample, :stream, :other)

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

    # @!group 3D Sound

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
    # @return [Integer] the currently selected driver number.
    integer_reader(:current_driver, :System_GetDriver)


    def driver_info(id)
      args = [id, "\0" * 512, 512, Guid.new] + (0...3).map { "\0" * SIZEOF_INT }
      FMOD.invoke(:System_GetDriverInfo, self, *args)
      Driver.send(:new, args)
    end

    # @!endgroup




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
    # A sound defined as FMOD_3D will by default play at the position of the
    # listener.
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


  end
end


