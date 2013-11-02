class HelloWorldLayer < Joybox::Core::Layer

  scene

  def on_enter
    @batch_node = CCSpriteBatchNode.batchNodeWithFile("Spritesheets/Sprites.pvr.ccz")
    self << @batch_node

    SpriteFrameCache.frames.add(:file_name => "Spritesheets/Sprites.plist")
    @ship = Sprite.new(:frame_name => "SpaceFlier_sm_1.png")
    @ship.position = [Screen.width * 0.1, Screen.height * 0.5]
    @batch_node.add_child(@ship, :z => 1)
  end
end
