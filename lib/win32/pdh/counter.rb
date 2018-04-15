require 'win32/pdh'
require 'win32/pdh/constants'

module Win32
  module Pdh
    class Counter
      def initialize(query:, path:)
        path = (path + "\0").encode('UTF-16LE')
        handle_pointer = FFI::MemoryPointer.new(:pointer)
        status = PdhFFI.PdhAddCounter(
          query,
          path,
          FFI::Pointer::NULL,
          handle_pointer,
        )
        raise PdhError, "PDH error #{Constants::LOOKUP[status]}!" unless status == Constants::ERROR_SUCCESS
        @handle = handle_pointer.read_pointer
      end
      
      def remove
        # Only allow removing once
        status = PdhFFI.PdhRemoveCounter(@handle) unless @handle.nil?
        raise PdhError, "PDH error #{Constants::LOOKUP[status]}!" unless status == Constants::ERROR_SUCCESS
        @handle = nil
      end
    end
  end
end
