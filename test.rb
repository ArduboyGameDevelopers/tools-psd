require 'psd'
require 'fileutils'

require_relative 'image_utils'
require_relative 'utils/animation'

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

source_h = ''
source_cpp = ''

source_h << "#ifndef IMAGES_H\n"
source_h << "#define IMAGES_H\n\n"

source_cpp << "include \"#{File.basename file_h}\""

animations.each { |animation|

  animation_name = animation.name.downcase

  source_h << "// #{animation.name}\n"
  (0..animation.frames.count-1).each { |index|

    frame = animation.frames[index]

    data = []
    frame.data.each { |byte|
      data << "0x#{byte.to_s 16}"
    }

    var_name = "#{animation_name}_#{index}"
    source_h << "extern const unsigned char #{var_name}[];\n"

    source_cpp << "\n\nPROGMEM const unsigned char #{var_name}[] = {\n"
    source_cpp << "  #{frame.x}, #{frame.y}, #{frame.width}, #{frame.height},\n"
    source_cpp << "  #{data.join ', '}\n"
    source_cpp << "};"
  }
}

source_h << "\n"
source_h << "#endif // IMAGES_H"

File.open(file_h, 'w') { |f| f.write source_h }
File.open(file_cpp, 'w') { |f| f.write source_cpp }

