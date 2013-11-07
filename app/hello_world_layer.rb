class HelloWorldLayer < Joybox::Core::Layer

  scene

  KNumAsteroids = 15
  KNumLasers = 5
  def on_enter
    @ship_points_per_sec_y = 0
    self.isAccelerometerEnabled = true
    self.isTouchEnabled = true

    @batch_node = CCSpriteBatchNode.batchNodeWithFile("Spritesheets/Sprites.pvr.ccz")
    self << @batch_node

    SpriteFrameCache.frames.add(:file_name => "Spritesheets/Sprites.plist")
    @ship = Sprite.new(:frame_name => "SpaceFlier_sm_1.png")
    @ship.position = [Screen.width * 0.1, Screen.height * 0.5]
    @batch_node.add_child(@ship, :z => 1)

    @next_asteroid = 0
    @next_asteroid_spawn = 0
    @asteroids = CCArray.alloc.initWithCapacity(KNumAsteroids)
    KNumAsteroids.times do |n|
      asteroid = Sprite.new(:frame_name => "asteroid.png")
      asteroid.visible = false
      @batch_node.addChild(asteroid)
      @asteroids.addObject(asteroid)
    end

    @next_ship_laser = 0
    @ship_lasers = CCArray.alloc.initWithCapacity(KNumLasers)
    KNumLasers.times do |n|
      ship_laser = Sprite.new(:frame_name => "laserbeam_blue.png")
      ship_laser.visible = false
      @batch_node.addChild(ship_laser)
      @ship_lasers.addObject(ship_laser)
    end

    @lives = 3
    current_time = Time.now.to_i
    @game_over_time = current_time + 3


    background_audio = BackgroundAudio.new
    background_audio.add(:audio => :space_game, :file_name => 'Sounds/SpaceGame.caf')
    background_audio.play(:space_game, :loop => true)

    @audio_effect = AudioEffect.new
    @audio_effect.add(:effect => :explosion_large,  :file_name => 'Sounds/explosion_large.caf')
    @audio_effect.add(:effect => :laser_ship,       :file_name => 'Sounds/laser_ship.caf')


    # 1) Create the CCParallaxNode
    @background_node = CCParallaxNode.node
    self << @background_node

    # 2) Create the sprites we'll add to the CCParallaxNode
    @spacedust_1    = Sprite.new(:file_name => "Backgrounds/bg_front_spacedust.png")
    @spacedust_2    = Sprite.new(:file_name => "Backgrounds/bg_front_spacedust.png")
    @planetsunrise  = Sprite.new(:file_name => "Backgrounds/bg_planetsunrise.png")
    @galaxy         = Sprite.new(:file_name => "Backgrounds/bg_galaxy.png")
    @spacialnomaly  = Sprite.new(:file_name => "Backgrounds/bg_spacialanomaly.png")
    @spacialnomaly2 = Sprite.new(:file_name => "Backgrounds/bg_spacialanomaly2.png")

    # 3) Determine relative movement speeds for space dust and background
    dust_speed = [0.1, 0.1]
    bg_speed = [0.05, 0.05]

    # 4) Add children to CCParallaxNode
    @background_node.addChild(@spacedust_1, z: 0, parallaxRatio: dust_speed, positionOffset: [0, Screen.half_height])
    @background_node.addChild(@spacedust_2, z: 0, parallaxRatio: dust_speed, positionOffset: [@spacedust_1.contentSize.width, Screen.half_height])
    @background_node.addChild(@galaxy, z: -1, parallaxRatio: bg_speed, positionOffset: [0, Screen.height * 0.7])
    @background_node.addChild(@planetsunrise, z: -1, parallaxRatio: bg_speed, positionOffset: [600, 0])
    @background_node.addChild(@spacialnomaly, z: -1, parallaxRatio: bg_speed, positionOffset: [900, Screen.height * 0.3])
    @background_node.addChild(@spacialnomaly2, z: -1, parallaxRatio: bg_speed, positionOffset: [1500, Screen.height * 0.9])

    schedule_update do |dt|
      update_background(dt)

      # Move by accelerometer
      max_y = Screen.height - @ship.contentSize.height.half;
      min_y = @ship.contentSize.height.half
      new_y = @ship.position.y + (@ship_points_per_sec_y * dt);
      new_y = [[new_y, min_y].max, max_y].min
      @ship.position = jbp(@ship.position.x, new_y);

      detect_laser_collision

      spawn_asteroid

      game_over?
    end

    on_touches_began do |touches, event|
      shoot_laser(touches, event)
    end

    stars = ["Particles/Stars1.plist", "Particles/Stars2.plist", "Particles/Stars3.plist"]
    stars.each do |star|
      stars_effect = CCParticleSystemQuad.particleWithFile(star)
      self.addChild(stars_effect, z: 1)
    end
  end

  def shoot_laser(touches, event)
    ship_laser = @ship_lasers.objectAtIndex(@next_ship_laser)
    @next_ship_laser += 1
    @next_ship_laser = 0 if @next_ship_laser >= @ship_lasers.count

    ship_laser.position = jbpAdd(@ship.position, jbp(ship_laser.contentSize.width.half, 0))
    ship_laser.visible = true
    ship_laser.stopAllActions


    move_action = Move.by(:position => [Screen.width, 0], :duration => 0.5)
    move_action_done = CCCallFuncN.actionWithTarget(self, selector: 'set_invisible:')
    move_sequence = Sequence.with(:actions => [move_action, move_action_done])
    ship_laser.run_action(move_sequence)
    @audio_effect.play(:laser_ship)
  end

  def update_background(dt)
    background_scroll_velocity = jbp(-1000, 0)
    @background_node.position = jbpAdd(@background_node.position, jbpMult(background_scroll_velocity, dt))

    space_dusts = [@spacedust_1, @spacedust_2]
    space_dusts.each do |space_dust|
      if @background_node.convertToWorldSpace(space_dust.position).x < -1 * space_dust.contentSize.width
        @background_node.increment_offset(:offset => jbp(2 * space_dust.contentSize.width, 0), :child => space_dust)
      end
    end
  end

  KFilteringFactor = 0.1
  KRestAccelX = -0.6
  KShipMaxPointsPerSec = Screen.half_height
  KMaxDiffX = 0.2
  def accelerometer(accelerometer, didAccelerate: acceleration)
    rolling_x = (acceleration.x * KFilteringFactor) + (rolling_x * (1.0 - KFilteringFactor))
    rolling_y = (acceleration.y * KFilteringFactor) + (rolling_y * (1.0 - KFilteringFactor))
    rolling_z = (acceleration.z * KFilteringFactor) + (rolling_z * (1.0 - KFilteringFactor))

    accel_x = acceleration.x - rolling_x
    accel_y = acceleration.y - rolling_y
    accel_z = acceleration.z - rolling_z

    accel_diff = accel_X - KRestAccelX
    accel_fraction = accel_diff / KMaxDiffX
    points_per_sec = KShipMaxPointsPerSec * accel_fraction

    @shipPointsPerSecY = points_per_sec
  end

  def spawn_asteroid
    current_time = Time.now.to_i

    if current_time > @next_asteroid_spawn
      rand_secs = random_value_between(0.20, andValue: 1.0)
      @next_asteroid_spawn = rand_secs + current_time

      rand_y = random_value_between(0.0, andValue: Screen.height)
      rand_duration = random_value_between(2.0, andValue: 10.0)

      asteroid = @asteroids.objectAtIndex(@next_asteroid)
      @next_asteroid += 1
      @next_asteroid = 0 if @next_asteroid >= @asteroids.count

      asteroid.stopAllActions
      asteroid.position = jbp(Screen.width + asteroid.contentSize.width.half, rand_y)
      asteroid.visible = true
      move_action = Move.by(:position => [-1 * Screen.width - asteroid.contentSize.width, 0], :duration => rand_duration)
      move_action_done = CCCallFuncN.actionWithTarget(self, selector: 'set_invisible:')
      move_sequence = Sequence.with(:actions => [move_action, move_action_done])
      asteroid.run_action(move_sequence)
    end
  end

  def detect_laser_collision
    @asteroids.each do |asteroid|
      next unless asteroid.visible

      @ship_lasers.each do |ship_laser|
        next unless ship_laser.visible

        if CGRectIntersectsRect(ship_laser.boundingBox, asteroid.boundingBox)
          ship_laser.visible = false
          asteroid.visible = false
          @audio_effect.play(:explosion_large)
          next
        end
      end

      if CGRectIntersectsRect(@ship.boundingBox, asteroid.boundingBox)
        asteroid.visible = false
        @ship.runAction(CCBlink.actionWithDuration(1.0, blinks: 9))
        @lives -= 1
        @audio_effect.play(:explosion_large)
      end

    end
  end

  # NOTE: Couldn't use rand((low..high))
  def random_value_between(low, andValue: high)
    rand * (high - low) + low
  end

  def set_invisible(node)
    node.visible = false
  end

  def game_over?
    if @lives <= 0
      @ship.stopAllActions
      @ship.visible = false
      end_scene(:end_reason_lose)
    elsif Time.now.to_i >= @game_over_time
      end_scene(:end_reason_win)
    end
  end

  def restart_tapped(sender)
    Joybox.director.replaceScene(
      CCTransitionZoomFlipX.transitionWithDuration(0.5, scene: HelloWorldLayer.scene)
    )
  end

  def end_scene(end_reason)
    return if @game_over
    @game_over = true

    if end_reason == :end_reason_win
      message = "You win!"
    elsif end_reason == :end_reason_lose
      message = "You lose!"
    end

    if ui_user_interface_idiom == UIUserInterfaceIdiomPad
      label = CCLabelBMFont.labelWithString(message, fntFile: "Fonts/Arial-hd.fnt")
    else
      label = CCLabelBMFont.labelWithString(message, fntFile: "Fonts/Arial.fnt")
    end
    label.scale = 0.1
    label.position = jbp(Screen.half_width, Screen.height * 0.6)
    self << label

    if ui_user_interface_idiom == UIUserInterfaceIdiomPad
      restart_label = CCLabelBMFont.labelWithString("Restart", fntFile: "Fonts/Arial-hd.fnt")
    else
      restart_label = CCLabelBMFont.labelWithString("Restart", fntFile: "Fonts/Arial.fnt")
    end
    restart_item = CCMenuItemLabel.itemWithLabel(restart_label, target: self, selector: 'restart_tapped:')
    restart_item.scale = 0.1
    restart_item.position = jbp(Screen.half_width, Screen.height * 0.4)
    menu = Menu.new(:position => [0, 0], :items => [restart_item])
    self << menu

    restart_item.run_action(Scale.to(:scale => 1.0, :duration => 0.5))
    label.run_action(Scale.to(:scale => 1.0, :duration => 1.0))
  end

  def ui_user_interface_idiom
    # FIXME
    return

    if UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad
      UIStoryboard.storyboardWithName "iPad-Storyboard", bundle: NSBundle.mainBundle
    else
      UIStoryboard.storyboardWithName "iPhone-Storyboard", bundle: NSBundle.mainBundle
    end
  end
end
