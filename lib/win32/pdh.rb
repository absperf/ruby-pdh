require 'win32/pdh/constants'

require 'ffi'

module Win32
  module Pdh
    class PdhError < StandardError
    end

    module PdhFFI
      extend FFI::Library
      ffi_lib 'Pdh.dll'
      ffi_convention :stdcall

      typedef :pointer, :pdh_hquery
      typedef :pointer, :pdh_hcounter
      typedef :uint, :pdh_status
      typedef :uint, :winbool

:pdh_status
      attach_function :PdhAddCounterW, [:pdh_hquery, :buffer_in, :buffer_in, :buffer_out], :pdh_status
      attach_function :PdhCollectQueryData, [:pdh_hquery], :pdh_status
      attach_function :PdhCloseQuery, [:buffer_in], :pdh_status
      attach_function :PdhEnumObjectItemsW, [:buffer_in, :buffer_in, :buffer_in, :buffer_out, :buffer_inout, :buffer_out, :buffer_inout, :uint, :uint], :pdh_status
      attach_function :PdhEnumObjectsW, [:buffer_in, :buffer_in, :buffer_out, :buffer_inout, :uint, :winbool], :pdh_status
      attach_function :PdhExpandWildCardPathW, [:buffer_in, :buffer_in, :buffer_out, :buffer_inout, :uint], :pdh_status
      attach_function :PdhGetFormattedCounterArray, [:pdh_hcounter, :uint, :buffer_inout, :buffer_out, :buffer_out], :pdh_status
      attach_function :PdhGetFormattedCounterValue, [:pdh_hcounter, :uint, :buffer_out, :buffer_out], :pdh_status
      attach_function :PdhGetRawCounterArray, [:pdh_hcounter, :buffer_inout, :buffer_out, :buffer_out], :pdh_status
      attach_function :PdhGetRawCounterValue, [:pdh_hcounter, :buffer_out, :buffer_out], :pdh_status
      attach_function :PdhIsRealTimeQuery, [:pdh_hquery], :winbool
      attach_function :PdhOpenQueryW, [:buffer_in, :buffer_in, :buffer_out], :pdh_status
      attach_function :PdhRemoveCounter, [:pdh_hcounter], :pdh_status
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
          status.nil? ? 1 : 0,
        )
      end

      raise PdhError, "PDH error #{Constants::LOOKUP[status]}!" unless status == Constants::ERROR_SUCCESS

      string = listbuffer.read_bytes(listsize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')

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

      raise PdhError, "PDH error #{Constants::LOOKUP[status]}!" unless status == Constants::ERROR_SUCCESS

      counterstring = counterbuffer.read_bytes(countersize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')
      instancestring = instancebuffer.read_bytes(instancesize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')

      enum = ItemEnum.new
      enum.counters = counterstring.split("\0").map(&:freeze).freeze
      enum.instances = instancestring.split("\0").map(&:freeze).freeze
      enum.freeze
    end

    ##
    # Expands a wildcard path into all matching counter paths.
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

      raise PdhError, "PDH error #{Constants::LOOKUP[status]}!" unless status == Constants::ERROR_SUCCESS

      liststring = listbuffer.read_bytes(listsize.read_uint * 2).force_encoding('UTF-16LE').encode('UTF-8')

      liststring.split("\0").map(&:freeze).freeze
    end
  end
end
