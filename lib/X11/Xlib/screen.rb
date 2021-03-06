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

class Screen
	include ForwardTo

	attr_reader :display
	forward_to  :root_window

	def initialize (display, screen)
		@display = display
		@screen  = screen.typecast(C::Screen)
	end

	C::Screen.layout.members.each {|name|
		next if [:display].member?(name)

		define_method name do
			@screen[name]
		end
	}

	def width (metric=false)
		@screen[metric ? :mwidth : :width]
	end

	def height (metric=false)
		@screen[metric ? :mheight : :height]
	end

	def root_window
		Window.new(@display, @screen[:root])
	end

	def windows
		Enumerator.new do |e|
			e.yield root_window

			root_window.subwindows(true).each {|win|
				e.yield win
			}
		end
	end

	memoize
	def to_i
		C::XScreenNumberOfScreen(to_ffi)
	end

	def to_ffi
		@screen.pointer
	end
end

end
