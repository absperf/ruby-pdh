require 'win32/pdh/constants'

require 'ffi'

module Win32
  module Pdh
    module PdhFFI
      extend FFI::Library
      ffi_lib :Pdh

      typedef :pointer, :pdh_hquery
      typedef :pointer, :pdh_hcounter
      typedef :uint, :pdh_status
      typedef :uint, :winbool

:pdh_status
      attach_function :PdhOpenQueryW, [:buffer_in, :buffer_in, :buffer_out], :pdh_status
      attach_function :PdhCloseQuery, [:buffer_in], :pdh_status
      attach_function :PdhEnumObjectsW, [:buffer_in, :buffer_in, :buffer_out, :buffer_inout, :uint, :winbool], :pdh_status
      attach_function :PdhEnumObjectItemsW, [:buffer_in, :buffer_in, :buffer_in, :buffer_out, :buffer_inout, :buffer_out, :buffer_inout, :uint, :uint], :pdh_status
    end

    ##
    # Uses PdhEnumObjects to enumerate objects at the given target.  Returns the
    # objects as a list.
    #
    # Params:
    # +source+:: The same as szDataSource
    # +machine+:: The same as szMachineName
    # +detail+:: Alias for dwDetailLevel, as a symbol.  May be :novice, :advanced, :expert, or :wizard.  Defaults to :novice.
    def self.enum_objects(source: nil, machine: nil, detail: :novice)
      source =
        if source.nil?
          FFI::Pointer::NULL
        else
          (source + "\0").encode('UTF-16LE')
        end
      machine =
        if machine.nil?
          FFI::Pointer::NULL
        else
          (machine + "\0").encode('UTF-16LE')
        end
      detail =
        case detail
        when :wizard
          Constants::PERF_DETAIL_WIZARD
        when :expert
          Constants::PERF_DETAIL_EXPERT
        when :advanced
          Constants::PERF_DETAIL_ADVANCED
        else
          Constants::PERF_DETAIL_NOVICE
        end

      # TODO: error handling

      # First get the required size
      bufsize = FFI::MemoryPointer.new(:uint)
      bufsize.write_uint(0)
      PdhFFI.PdhEnumObjectsW(
        source,
        machine,
        FFI::Pointer::NULL,
        bufsize,
        detail,
        1,
      )

      # Allocate the buffer
      buffer = FFI::Buffer.new(:uint16, bufsize.read_uint)

      # Fill the buffer
      PdhFFI.PdhEnumObjectsW(
        source,
        machine,
        buffer,
        bufsize,
        detail,
        0,
      )

      string = buffer.read_bytes(bufsize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')

      # Split and return objects
      string.split("\0")
    end

    ItemEnum = Struct.new('ItemEnum', :instances, :counters)

    ##
    # Enumerates an object's counter and instance names.  Returns an ItemEnum
    # with the results.
    def self.enum_object_items(object:, source: nil, machine: nil, detail: :novice)
      object = (object + "\0").encode('UTF-16LE')
      source =
        if source.nil?
          FFI::Pointer::NULL
        else
          (source + "\0").encode('UTF-16LE')
        end
      machine =
        if machine.nil?
          FFI::Pointer::NULL
        else
          (machine + "\0").encode('UTF-16LE')
        end
      detail =
        case detail
        when :wizard
          Constants::PERF_DETAIL_WIZARD
        when :expert
          Constants::PERF_DETAIL_EXPERT
        when :advanced
          Constants::PERF_DETAIL_ADVANCED
        else
          Constants::PERF_DETAIL_NOVICE
        end

      countersize = FFI::MemoryPointer.new(:uint)
      instancesize = FFI::MemoryPointer.new(:uint)
      countersize.write_uint(0)
      instancesize.write_uint(0)
      counterbuffer = FFI::Pointer::NULL
      instancebuffer = FFI::Pointer::NULL
      status = nil
      while status.nil? || status == Constants::PDH_MORE_DATA
        unless status.nil?
          counterbuffer = FFI::Buffer.new(:uint16, countersize.read_uint)
          instancebuffer = FFI::Buffer.new(:uint16, instancesize.read_uint)
        end
        status = PdhFFI.PdhEnumObjectItemsW(
          source,
          machine,
          object,
          counterbuffer,
          countersize,
          instancebuffer,
          instancesize,
          detail,
          0,
        )
      end

      # TODO: improve error handling
      raise "PDH error #{Constants::LOOKUP[status]}!" unless status == Constants::ERROR_SUCCESS

      counterstring = counterbuffer.read_bytes(countersize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')
      instancestring = instancebuffer.read_bytes(instancesize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')

      enum = ItemEnum.new
      enum.counters = counterstring.split("\0").map(&:freeze).freeze
      enum.instances = instancestring.split("\0").map(&:freeze).freeze
      enum.freeze
    end
  end
end
