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
# THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> OR
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

require 'X11/Xlib/window/attributes'
require 'X11/Xlib/window/properties'

module X11

class Window
  attr_reader :display, :parent, :revert_to

  def initialize (display, window)
    @display = display
    @window  = window

    if nil?
      (methods - Object.instance_methods).each {|name|
        define_singleton_method name do |*|
          raise BadWindow
        end
      }
    else
      self.revert_to = nil
    end
  end

  def root
    root     = FFI::MemoryPointer.new :Window
    parent   = FFI::MemoryPointer.new :Window
    number   = FFI::MemoryPointer.new :uint
    children = FFI::MemoryPointer.new :pointer

    C::XQueryTree(display.to_ffi, id, root, parent, children, number)
    C::XFree(children.typecast(:pointer))

    Window.new(display, root.typecast(:Window))
  end

  def parent
    root     = FFI::MemoryPointer.new :Window
    parent   = FFI::MemoryPointer.new :Window
    number   = FFI::MemoryPointer.new :uint
    children = FFI::MemoryPointer.new :pointer

    C::XQueryTree(display.to_ffi, id, root, parent, children, number)
    C::XFree(children.typecast(:pointer))

    Window.new(display, parent.typecast(:Window))
  end

  def id
    @window
  end; alias hash id

  def == (value)
    id == value.id
  end

  def nil?
    id.zero?
  end

  def drawable?
    true
  end

  def revert_to= (value)
    @revert_to = if value.is_a?(Integer)
      RevertTo.key(value)
    else
      self.revert_to = RevertTo[value] || 0
    end
  end

  def attributes
    attr = FFI::MemoryPointer.new(C::XWindowAttributes)

    C::XGetWindowAttributes(display.to_ffi, to_ffi, attr)

    Attributes.new(attr)
  end

  def properties
    Properties.new(self)
  end

  def move (x, y)
    C::XMoveWindow(display.to_ffi, to_ffi, x, y)

    display.flush
  end

  def resize (width, height)
    C::XResizeWindow(display.to_ffi, to_ffi, width, height)

    display.flush
  end

  def raise
    C::XRaiseWindow(display.to_ffi, to_ffi)
    
    display.flush
  end

  def subwindows
    result   = []
    root     = FFI::MemoryPointer.new :Window
    parent   = FFI::MemoryPointer.new :Window
    number   = FFI::MemoryPointer.new :uint
    children = FFI::MemoryPointer.new :pointer

    C::XQueryTree(display.to_ffi, id, root, parent, children, number)

    return result if children.typecast(:pointer).null?

    children.typecast(:pointer).read_array_of(:Window, number.typecast(:uint)).each {|win|
      result << Window.new(display, win)
    }

    C::XFree(children.typecast(:pointer))

    result
  end

  def grab_pointer (owner_events=true, event_mask=Mask::Event[:NoEvent], pointer_mode=:sync, keyboard_mode=:async, confine_to=0, cursor=0, time=0)
    C::XGrabPointer(display.to_ffi, to_ffi, !!owner_events, event_mask.to_ffi, mode2int(pointer_mode), mode2int(keyboard_mode), confine_to.to_ffi, cursor.to_ffi, time).zero?
  end

  def ungrab_pointer (time=0)
    display.ungrab_pointer(time)
  end

  def keysym_to_keycode (keysym)
    C::XKeysymToKeycode(to_ffi, keysym)
  end

  def grab_key (keycode, modifiers=0, owner_events=true, pointer_mode=:async, keyboard_mode=:sync)
    C::XGrabKey(display.to_ffi, keycode.to_keycode, modifiers, to_ffi, !!owner_events, mode2int(pointer_mode), mode2int(keyboard_mode))
  end

  def ungrab_key (keycode, modifiers=0)
    C::XUngrabKey(display.to_ffi, keycode.to_keycode, modifiers, to_ffi)
  end

  def grab_button (button, modifiers=0, owner_events=true, event_mask=Mask::Event[:ButtonPress], pointer_mode=:async, keyboard_mode=:sync, confine_to=0, cursor=0)
    C::XGrabButton(display.to_ffi, button, modifiers, to_ffi, !!owner_events, event_mask.to_ffi, mode2int(pointer_mode), mode2int(keyboard_mode), confine_to.to_ffi, cursor.to_ffi)
  end

  def ungrab_button (button, modifiers=0)
    C::XUngrabButton(display.to_ffi, button, modifiers, to_ffi)
  end

  def pointer_on?
    root  = FFI::MemoryPointer.new :Window
    child = FFI::MemoryPointer.new :Window
    dummy = FFI::MemoryPointer.new :int

    C::XQueryPointer(display.to_ffi, to_ffi, root, child, dummy, dummy, dummy, dummy, dummy)

    Window.new(display, child.typecast(:Window))
  end

  def pointer_at? (on_root=false)
    dummy = FFI::MemoryPointer.new :Window
    y     = FFI::MemoryPointer.new :int
    x     = FFI::MemoryPointer.new :int

    if on_root
      C::XQueryPointer(display.to_ffi, to_ffi, dummy, dummy, x, y, dummy, dummy, dummy)
    else
      C::XQueryPointer(display.to_ffi, to_ffi, dummy, dummy, dummy, dummy, x, y, dummy)
    end

    [x.typecast(:int), y.typecast(:int)]
  end

  def next_event (mask=Mask::Event[:NoEvent])
    event = FFI::MemoryPointer.new(C::XEvent)

    C::XWindowEvent(display.to_ffi, to_ffi, mask.to_ffi, event)

    Event.new(event)
  end

  def to_ffi
    id
  end

  def inspect
    begin
      with attributes do |attr|
        "#<X11::Window: #{attr.width}x#{attr.height} (#{attr.x}; #{attr.y})>"
      end
    rescue Exception => e
      "#<X11::Window: invalid window>"
    end
  end

  private

  GRAB_MODE = { :sync => false, :async => true }

  def mode2int (mode)
    (mode == true or GRAB_MODE[mode]) ? 1 : 0
  end
end

end
