#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
# 
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY meh ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL meh OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are those of the
# authors and should not be interpreted as representing official policies, either expressed
# or implied.
#++

module X11

class Display
  def self.open (*args)
    name, options = if args.first.is_a?(Hash)
      [nil, args.first]
    else
      args
    end

    with X11::C::XOpenDisplay(name) do |pointer|
      raise ArgumentError, "could not connect to display #{name}" if pointer.null?

      Display.new(pointer, options)
    end
  end

  include ForwardTo

  attr_reader :options
  forward_to  :default_screen

  def initialize (pointer, options={})
    @display = pointer.is_a?(C::Display) ? pointer : C::Display.new(pointer)

    @options = {
      :flush => true
    }.merge(options || {})
  end

  C::Display.layout.members.each_with_index {|name, index|
    define_method name do
      @display[name]
    end
  }

  def flush
    flush! if options[:flush]

    self
  end

  def flush!
    C::XFlush(to_ffi)

    self
  end

  def screen (which)
    Screen.new(self, @display[:screens] + (which * C::Screen.size))
  end

  def default_screen
    screen(@display[:default_screen])
  end

  def screens
    Enumerator.new {
      (0 ... @display[:nscreens]).map {|i|
        yield screen(i)
      }
    }
  end

  def grab_pointer (*args)
    default_screen.root_window.grab_pointer(*args)
  end

  def ungrab_pointer (time=0)
    C::XUngrabPointer(to_ffi, time)
  end

  def keysym_to_keycode (keysym)
    C::XKeysymToKeycode(to_ffi, keysym)
  end

  def focused
    window = FFI::MemoryPointer.new :Window
    revert = FFI::MemoryPointer.new :int

    C::XGetInputFocus(to_ffi, window, revert)

    Window.new(self, window.typecast(:Window)).tap {|w|
      w.revert_to = revert.typecast(:int)
    }
  end

  def focus (window, revert=:ToParent, time=0)
    C::XSetInputFocus(to_ffi, window.to_ffi, revert.is_a?(Integer) ? revert : RevertTo[revert], time)
  end

  def allow_events (mode, time=0)
    C::XAllowEvents(to_ffi, mode, time)
  end

  def event_matches? (event, what)
    case what
      when Array         then what.any? { |what| event_matches?(event, what) }
      when Symbol        then event.name == what
      when Bitmap::Value then event.mask.any? { |name| what.has?(name) }
      when Regexp        then event.name.to_s.match(what)
    end
  end

  def next_event (what=nil, options=nil, &block)
    what, options = if what.is_a?(Hash)
      [Mask::Event.all, what]
    else
      [what, options || {}]
    end

    event    = FFI::MemoryPointer.new(C::XEvent)
    callback = FFI::Function.new(:Bool, [:pointer, :pointer, :pointer]) do |display, event|
      event = Event.new(event)

      with event_matches?(event, what) do |ok|
        (block && ok) ? block.call(event) : ok
      end
    end

    unless options[:blocking?] == false
      unless options[:delete] == false
        C::XIfEvent(to_ffi, event, callback, nil)
      else
        C::XPeekIfEvent(to_ffi, event, callback, nil)
      end
    else
      if options[:delete] == true
        raise ArgumentError, 'cannot delete and not block at the same time'
      end

      C::XCheckIfEvent(to_ffi, event, callback, nil) or return
    end

    Event.new(event)
  end

  def each_event (what=nil, options=nil, &block)
    return unless block

    catch(:skip) {
      loop {
        next_event(what, options).tap {|event|
          if !event
            return if options[:blocking] == false
            next
          end

          block.call event
        }
      }
    }
  end

  def close
    C::XCloseDisplay(to_ffi)

    methods.each {|name|
      next if (Object.instance_method(name) rescue false)

      define_singleton_method name do |*|
        raise RuntimeError, 'this Display is unusable because it has been closed'
      end
    }
  end

  def to_ffi
    @display.pointer
  end
end

end
