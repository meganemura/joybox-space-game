class CCParallaxNode
  def increment_offset(options)
    offset = options[:offset]
    child = options[:child]

    # TODO: Doesn't work
    # self.parallaxArray.each do |point|
    #   point.setOffset(jbpAdd(point.offset, offset)) if point.child == child
    # end
  end
end
