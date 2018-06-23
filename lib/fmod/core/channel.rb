
require_relative 'channel_control'

module FMOD
  class Channel < ChannelControl

    include Fiddle

    float_reader(:frequency, :Channel_GetFrequency)
    float_writer(:frequency=, :Channel_SetFrequency)

    bool_reader(:virtual?, :Channel_IsVirtual)

    integer_reader(:index, :Channel_GetIndex)

    integer_reader(:priority, :Channel_GetPriority)
    integer_writer(:priority=, :Channel_SetPriority, 0, 256)

    integer_reader(:loop_count, :Channel_GetLoopCount)
    integer_writer(:loop_count=, :Channel_SetLoopCount, -1)

    def current_sound
      FMOD.invoke(:Channel_GetCurrentSound, self, sound = int_ptr)
      Sound.new(sound)
    end

    def position(unit = TimeUnit::MS)
      buffer = "\0" * SIZEOF_INT
      FMOD.invoke(:Channel_SetPosition, self, buffer, unit)
      buffer.unpack1('L')
    end

    def seek(position, unit = TimeUnit::MS)
      position = 0 if position < 0
      FMOD.invoke(:Channel_SetPosition, self, position, unit)
      self
    end

    def group
      FMOD.invoke(:Channel_GetChannelGroup, self, group = int_ptr)
      ChannelGroup.new(group)
    end

    def group=(channel_group)
      FMOD.check_type(channel_group, ChannelGroup)
      FMOD.invoke(:Channel_SetChannelGroup, self, channel_group)
      channel_group
    end

    ##
    # Retrieves the loop points for a sound.
    # @param start_unit [Integer] The time format used for the returned loop
    #   start point.
    #   @see TimeUnit
    # @param end_unit [Integer] The time format used for the returned loop end
    #   point.
    #   @see TimeUnit
    # @return [Array(Integer, Integer)] the loop points in an array where the
    #   first element is the start loop point, and second element is the end
    #   loop point in the requested time units.
    def loop_points(start_unit = TimeUnit::MS, end_unit = TimeUnit::MS)
      loop_start, loop_end = "\0" * SIZEOF_INT, "\0" * SIZEOF_INT
      FMOD.invoke(:Channel_GetLoopPoints, self, loop_start,
        start_unit, loop_end, end_unit)
      [loop_start.unpack1('L'), loop_end.unpack1('L')]
    end

    ##
    # Sets the loop points within a sound
    #
    # If a sound was 44100 samples long and you wanted to loop the whole sound,
    # _loop_start_ would be 0, and _loop_end_ would be 44099, not 44100. You
    # wouldn't use milliseconds in this case because they are not sample
    # accurate.
    #
    # If loop end is smaller or equal to loop start, it will result in an error.
    #
    # If loop start or loop end is larger than the length of the sound, it will
    # result in an error
    #
    # @param loop_start [Integer] The loop start point. This point in time is
    #   played, so it is inclusive.
    # @param loop_end [Integer] The loop end point. This point in time is
    #   played, so it is inclusive
    # @param start_unit [Integer] The time format used for the loop start point.
    #   @see TimeUnit
    # @param end_unit [Integer] The time format used for the loop end point.
    #   @see TimeUnit
    def set_loop(loop_start, loop_end, start_unit = TimeUnit::MS, end_unit = TimeUnit::MS)
      FMOD.invoke(:Channel_SetLoopPoints, self, loop_start,
        start_unit, loop_end, end_unit)
      self
    end
  end
end