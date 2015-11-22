require 'psd'
require 'fileutils'

require_relative 'image_utils'
Dir['utils/**/*.rb'].each { |source_file| require_relative source_file }


TRANSPARENT_COLOR = 0xffffffff # white is transparent

file = '/Users/weee/Documents/arduboy/walk.psd'

def process_layer(layer)
  ImageUtils::make_frame(layer.name, layer.image.to_png, TRANSPARENT_COLOR)
end

def process_group(group)
  puts group.name

  animation = Animation.new group.name
  group.children.each { |child|
    next unless child.is_a? PSD::Node::Layer
    animation.add_frame process_layer(child)
  }

  animation
end

animations = []

PSD.open(file) do |psd|
  children = psd.tree.children
  children.each { |child|
    animations.push process_group(child) if child.is_a? PSD::Node::Group
  }
end

dir_out = 'out'
FileUtils.rmtree dir_out
FileUtils.mkpath dir_out

file_h = "#{dir_out}/images.h"
file_cpp = "#{dir_out}/images.cpp"

source_h = SourceWriter.new
source_cpp = SourceWriter.new

source_h.println '#ifndef IMAGES_H'
source_h.println '#define IMAGES_H'
source_h.println
source_h.println "#include \"animation.h\""

source_cpp.println "#include <avr/pgmspace.h>"
source_cpp.println "#include \"#{File.basename file_h}\""

animations.each { |animation|

  animation_name = animation.name.downcase

  frames = animation.frames
  names = []

  (0..frames.count-1).each { |index|

    frame = frames[index]

    data = []
    frame.data.each { |byte|
      data << "0x#{byte.to_s 16}"
    }

    var_name = "#{animation_name}_#{index}"
    names << var_name

    source_cpp.println
    source_cpp.println "PROGMEM static const unsigned char #{var_name}[] ="
    source_cpp.block_open
    source_cpp.println "#{frame.x}, #{frame.y}, #{frame.width}, #{frame.height},"
    source_cpp.println "#{data.join ', '}"
    source_cpp.block_close ';'
  }

  frames_name = "#{animation_name}_frames"

  source_cpp.println
  source_cpp.println "static const FrameData #{frames_name}[] ="

  source_cpp.block_open
  names.each do |name|
    source_cpp.println "#{name},"
  end
  source_cpp.block_close ';'

  # const Animation animation_walk = CreateAnimation(walk_frames, sizeof(walk_frames) / sizeof(FrameData));

  source_h.println
  source_h.println "extern const Animation animation_#{animation_name};"

  source_cpp.println
  source_cpp.println "const Animation animation_#{animation_name} = CreateAnimation(#{frames_name}, #{frames.length});"
}

source_h.println
source_h.println '#endif // IMAGES_H'

source_h.write_to_file file_h
source_cpp.write_to_file file_cpp