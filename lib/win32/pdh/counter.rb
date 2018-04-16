require 'ffi'

require 'win32/pdh'
require 'win32/pdh/constants'

module Win32
  module Pdh
    class Counter
      class PDH_COUNTER_PATH_ELEMENTS < FFI::Struct
        layout(
          :szMachineName, :pointer,
          :szObjectName, :pointer,
          :szInstanceName, :pointer,
          :szParentInstance, :pointer,
          :dwInstanceIndex, :uint,
          :szCounterName, :pointer,
        )
      end
      class PDH_COUNTER_INFO < FFI::Struct
        layout(
          :dwLength, :uint,
          :dwType, :uint,
          :CVersion, :uint,
          :CStatus, :uint,
          :lScale, :uint,
          :lDefaultScale, :uint,
          :dwUserData, :pointer,
          :dwQueryUserData, :pointer,
          :szFullPath, :pointer,
          :CounterPath, PDH_COUNTER_PATH_ELEMENTS,
          :szExplainText, :pointer,
          :DataBuffer, :uint,
        )
      end

      class PDH_FMT_COUNTERVALUE_VALUE < FFI::Union
        layout(
          :longValue, :int32,
          :doubleValue, :double,
          :largeValue, :int64,
          :AnsiStringValue, :pointer,
          :WideStringValue, :pointer,
        )
      end

      class PDH_FMT_COUNTERVALUE < FFI::Struct
        layout(
          :CStatus, :uint32,
          :value, PDH_FMT_COUNTERVALUE_VALUE,
        )
      end

      attr_accessor :type, :version, :status, :scale, :default_scale, :full_path, :machine_name, :object_name, :instance_name, :instance_index, :counter_name, :explain_text

      def initialize(query:, path:)
        path = (path + "\0").encode('UTF-16LE')
        handle_pointer = FFI::MemoryPointer.new(:pointer)
        status = PdhFFI.PdhAddCounterW(
          query,
          path,
          FFI::Pointer::NULL,
          handle_pointer,
        )
        Pdh.check_status status
        @handle = handle_pointer.read_pointer
        load_info
      end
      
      def remove
        # Only allow removing once
        unless @handle.nil?
          status = PdhFFI.PdhRemoveCounter(@handle) unless @handle.nil?
          Pdh.check_status status
          @handle = nil
        end
      end

      alias_method :close, :remove

      def load_info
        buffersize = FFI::MemoryPointer.new(:uint)
        buffersize.write_uint(0)
        buffer = FFI::Pointer::NULL
        status = nil
        while status.nil? || status == Constants::PDH_MORE_DATA
          buffer = FFI::Buffer.new(:uint16, buffersize.read_uint) unless status.nil?
          status = PdhFFI.PdhGetCounterInfoW(@handle, :false, buffersize, buffer)
        end
        Pdh.check_status status

        info = PDH_COUNTER_INFO.new(buffer)
        @type = info[:dwType]
        @version = info[:CVersion]
        @status = info[:CStatus]
        @scale = info[:lScale]
        @default_scale = info[:lDefaultScale]
        @full_path = Pdh.read_cwstr(info[:szFullPath]).freeze
        counter_path = info[:CounterPath]
        @machine_name = Pdh.read_cwstr(counter_path[:szMachineName]).freeze
        @object_name = Pdh.read_cwstr(counter_path[:szObjectName]).freeze
        @instance_name = Pdh.read_cwstr(counter_path[:szInstanceName]).freeze
        @instance_index = counter_path[:dwInstanceIndex]
        @counter_name = Pdh.read_cwstr(counter_path[:szCounterName]).freeze
        @explain_text = Pdh.read_cwstr(info[:szExplainText]).freeze
        Pdh.check_status @status
      end

      def good?
        @status == Constants::ERROR_SUCCESS
      end

      # Get the PDH_FMT_COUNTERVALUE_VALUE given the format, checking status and
      # raising an exception if necessary
      def get(format)
        value = PDH_FMT_COUNTERVALUE.new
        status = PdhFFI.PdhGetFormattedCounterValue(
          @handle,
          format,
          FFI::Pointer::NULL,
          value,
        )
        Pdh.check_status status
        Pdh.check_status value[:CStatus]
        value[:value]
      end

      ##
      # Get value as a double
      def get_double
        get(Constants::PDH_FMT_DOUBLE)[:doubleValue]
      end

      ##
      # Get value as a 64-bit integer
      def get_large
        get(Constants::PDH_FMT_LARGE)[:largeValue]
      end

      ##
      # Get value as a 32-bit integer
      def get_long
        get(Constants::PDH_FMT_LONG)[:longValue]
      end
    end
  end
end
