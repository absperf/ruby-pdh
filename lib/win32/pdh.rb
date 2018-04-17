require 'win32/pdh/constants'

require 'ffi'

module Win32
  module Pdh
    ##
    # Simple error subclass.  Currently, this is what type all exceptions
    # directly raised by this library are.
    class PdhError < StandardError
      def initialize(status)
        super("PDH error #{Constants::NAMES[status]}: #{Constants::MESSAGES[status]}")
      end
    end

    ##
    # Simple convenience method that checks the status and raises an exception
    # unless it's a successful status.
    def self.check_status(status)
      raise PdhError, status unless status == Constants::ERROR_SUCCESS
    end

    ##
    # Gets the length of a cwstr (null-terminated UTF-16 string) in characters
    # (16-bit units).
    #
    # Returns nil if the pointer is null
    def self.strlen_cwstr(pointer)
      return nil if pointer.null?

      # Clone pointer, so we don't modify the original.
      pointer = FFI::Pointer.new(pointer)
      length = 0
      until pointer.get_uint16(0) == 0
        length += 1
        # Need to proceed 2 bytes at a time; Ruby ffi gives no special pointer
        # arithmetic by type.
        pointer += 2
      end

      length
    end

    ##
    # Takes a pointer to null-terminated utf-16 data and reads it into a utf-8 encoded string.
    #
    # If pointer is null, return nil instead of a string.
    def self.read_cwstr(pointer)
      return nil if pointer.null?

      # length in wchars
      length = strlen_cwstr(pointer)

      pointer.read_bytes(length * 2).force_encoding('UTF-16LE').encode('UTF-8')
    end

    ##
    # Container namespace for all Pdh functions.
    module PdhFFI
      extend FFI::Library
      ffi_lib 'Pdh.dll'
      ffi_convention :stdcall

      typedef :pointer, :pdh_hquery
      typedef :pointer, :pdh_hcounter
      typedef :uint, :pdh_status
      enum :winbool, [:false, 0, :true]

:pdh_status
      attach_function :PdhAddCounterW, [:pdh_hquery, :buffer_in, :buffer_in, :buffer_out], :pdh_status
      attach_function :PdhCalculateCounterFromRawValue, [:pdh_hcounter, :uint, :buffer_in, :buffer_in, :buffer_out], :pdh_status
      attach_function :PdhCollectQueryData, [:pdh_hquery], :pdh_status
      attach_function :PdhCloseQuery, [:buffer_in], :pdh_status
      attach_function :PdhEnumObjectItemsW, [:buffer_in, :buffer_in, :buffer_in, :buffer_out, :buffer_inout, :buffer_out, :buffer_inout, :uint, :uint], :pdh_status
      attach_function :PdhEnumObjectsW, [:buffer_in, :buffer_in, :buffer_out, :buffer_inout, :uint, :winbool], :pdh_status
      attach_function :PdhExpandWildCardPathW, [:buffer_in, :buffer_in, :buffer_out, :buffer_inout, :uint], :pdh_status

      # We use Ascii instead of Wide for this because reading null-terminated
      # utf-16 buffers with Ruby FFI is not easy.
      attach_function :PdhGetCounterInfoW, [:pdh_hcounter, :winbool, :buffer_inout, :buffer_out], :pdh_status
      attach_function :PdhGetFormattedCounterArrayW, [:pdh_hcounter, :uint, :buffer_inout, :buffer_out, :buffer_out], :pdh_status
      attach_function :PdhGetFormattedCounterValue, [:pdh_hcounter, :uint, :buffer_out, :buffer_out], :pdh_status
      attach_function :PdhGetRawCounterArrayW, [:pdh_hcounter, :buffer_inout, :buffer_out, :buffer_out], :pdh_status
      attach_function :PdhGetRawCounterValue, [:pdh_hcounter, :buffer_out, :buffer_out], :pdh_status
      attach_function :PdhIsRealTimeQuery, [:pdh_hquery], :winbool
      attach_function :PdhOpenQueryW, [:buffer_in, :buffer_in, :buffer_out], :pdh_status
      attach_function :PdhRemoveCounter, [:pdh_hcounter], :pdh_status
    end

    ##
    # Uses PdhEnumObjects to enumerate objects at the given target.  Returns the
    # objects as an array of strings.
    #
    # PdhEnumObjects: https://msdn.microsoft.com/en-us/library/windows/desktop/aa372600(v=vs.85).aspx
    #
    # Params:
    # source:: The same as szDataSource
    # machine:: The same as szMachineName
    # detail:: Alias for dwDetailLevel, as a symbol.  May be :novice, :advanced, :expert, or :wizard.  Defaults to :novice.
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

      listsize = FFI::MemoryPointer.new(:uint)
      listsize.write_uint(0)
      listbuffer = FFI::Pointer::NULL
      status = nil
      while status.nil? || status == Constants::PDH_MORE_DATA
        listbuffer = FFI::Buffer.new(:uint16, listsize.read_uint) unless status.nil?

        status = PdhFFI.PdhEnumObjectsW(
          source,
          machine,
          listbuffer,
          listsize,
          detail,
          status.nil? ? :true : :false,
        )
      end

      Pdh.check_status status

      string = listbuffer.read_bytes(listsize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')

      # Split and return objects
      string.split("\0")
    end

    ##
    # Structure of instances and counters, for ::enum_object_items
    ItemEnum = Struct.new('ItemEnum', :instances, :counters)

    ##
    # Enumerates an object's counter and instance names.  Returns an ItemEnum
    # with the results.
    #
    # Uses PdhEnumObjectItems: https://msdn.microsoft.com/en-us/library/windows/desktop/aa372595(v=vs.85).aspx
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

      Pdh.check_status status

      counterstring = counterbuffer.read_bytes(countersize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')
      instancestring = instancebuffer.read_bytes(instancesize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')

      enum = ItemEnum.new
      enum.counters = counterstring.split("\0").map(&:freeze).freeze
      enum.instances = instancestring.split("\0").map(&:freeze).freeze
      enum.freeze
    end

    ##
    # Expands a wildcard path into all matching counter paths.
    #
    # Returns a frozen array of frozen strings.
    #
    # Uses PdhExpandWildCardPath: https://msdn.microsoft.com/en-us/library/windows/desktop/aa372606(v=vs.85).aspx
    def self.expand_wildcards(path:, source: nil, expand_counters: true, expand_instances: true)
      path = (path + "\0").encode('UTF-16LE')
      source =
        if source.nil?
          FFI::Pointer::NULL
        else
          (source + "\0").encode('UTF-16LE')
        end

      flags = 0
      flags |= PDH_NOEXPANDCOUNTERS unless expand_counters
      flags |= PDH_NOEXPANDINSTANCES unless expand_instances

      listsize = FFI::MemoryPointer.new(:uint)
      listsize.write_uint(0)
      listbuffer = FFI::Pointer::NULL
      status = nil
      while status.nil? || status == Constants::PDH_MORE_DATA
        listbuffer = FFI::Buffer.new(:uint16, listsize.read_uint) unless status.nil?
        status = PdhFFI.PdhExpandWildCardPathW(
          source,
          path,
          listbuffer,
          listsize,
          flags,
        )
      end

      Pdh.check_status status

      liststring = listbuffer.read_bytes(listsize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')

      liststring.split("\0").map(&:freeze).freeze
    end
  end
end
