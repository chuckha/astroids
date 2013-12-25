import 'dart:html';
import 'dart:math' as math;

List<bool> keysDown = new List<bool>(256);
ImageElement sheet = new ImageElement(src: "images/sheet.png", width: 256, height:256);
List<Ticker> tickers = [];
List<Astroid> astroids = [];
bool loseGame = false;
bool winGame = false;

class Ticker {
  void tick() {}
}

class Renderer {
  void render(CanvasRenderingContext2D ctx) {}
}

// Rectangle positions only?
class Position {
  double _x, _y;
  int _width, _height;
  static int CANVAS_HEIGHT = 500;
  static int CANVAS_WIDTH = 500;
  
  double bottom() {
    return _y + _height;
  }
  double top() {
    return _y;
  }
  double left() {
    return _x;
  }
  double right() {
    return _x + _width;
  }
  bool collide(Position rectangle) {
    return !(rectangle.bottom() < this.top() 
        || rectangle.left() > this.right() 
        || rectangle.top() > this.bottom()
        || rectangle.right() < this.left());
  }
  void mirror() {
    if (_x > CANVAS_WIDTH) {
      _x -= CANVAS_WIDTH + _width;
    }
    if (_y > CANVAS_HEIGHT) {
      _y -= CANVAS_HEIGHT + _height;
    }
    if (_x < -_width) {
      _x += CANVAS_WIDTH + _width;
    }
    if (_y < -_height) {
      _y += CANVAS_HEIGHT + _height;
    }
  }
}

class Astroid extends Position implements Ticker, Renderer {
  double _x, _y, _dx, _dy;
  int _width, _height, _power;
  
  Astroid(int width, height, power, double x, y, dx, dy) {
    _x = x;
    _y = y;
    _dx = dx;
    _dy = dy;
    _power = power;
    _width = width;
    _height = height;
  }
  
  void tick(){
    _x += _dx;
    _y += _dy;
    mirror();
  }
  void render(CanvasRenderingContext2D ctx) {
    ctx.save();
    ctx.drawImageScaledFromSource(sheet, 16, 0, 8, 8, _x, _y, _width, _height);
    ctx.restore();
  }
  bool shot(Bullet bullet) {
    var collided = collide(bullet);
    if (collided) {
      explode();
    }
    return collided;
  }
  void explode() {
    if (_power > 0) {
      var rand = new math.Random();
      var dx = rand.nextDouble() + .5 * _dx;
      var dy = rand.nextDouble() + .5 * _dy;
      astroids.add(new Astroid(_width-16, _height-16, _power-1, _x, _y, -dx, dy));
      astroids.add(new Astroid(_width-16, _height-16, _power-1, _x, _y, dx, -dy));
    }
    astroids.remove(this);
  }
}

class Bullet extends Position implements Ticker, Renderer {
  double _x, _y, angle;
  int _width = 2;
  int _height = 2;
  int tickCount = 0;
  Bullet(this._x, this._y, this.angle);
  void tick() {
    tickCount++;
    var as = astroids.toList();
    for (var astroid in as) {
      if (astroid.shot(this)) {
        // TODO: Fixme :)
        tickCount = 10000;
      }
    }
    _x += math.sin(angle)* 10;
    _y += -math.cos(angle) * 10;
    mirror();
  }
  void render(CanvasRenderingContext2D ctx) {
    ctx.save();
    ctx.drawImageScaledFromSource(sheet, 8, 0, 2, 2, _x, _y, _width, _height);
    ctx.restore();
  }
}

class Ship extends Position implements Ticker, Renderer {
  int _width, _height;
  double _x, _y, angle;
  List<Bullet> bullets = [];
  int tickCount, lastShot;
  static double DELTA = .02;
  static int MAX_BULLET_AGE = 25;
  static double MAX_SPEED = 6.0;
  
  Ship() {
    _x = 250.0;
    _y = 250.0;
    _width = 16;
    _height = 16;
    angle = 0.0;
    tickCount = 0;
    lastShot = -50;
  }
  
  double xS = 0.0;
  double yS = 0.0;
  
  void tick() {
    tickCount++;
    double theta = 0.0;
    double rotateSpeed = 5*math.PI/180;
    int velocity = 8;

    // Always get to zero
    if (xS.abs() <= DELTA) {
      xS = 0.0;
    }
    if (yS.abs() <= DELTA) {
      yS = 0.0;
    }
            
    // Left
    if (keysDown[37]) {
      theta -= rotateSpeed;
    }
    // Right
    if (keysDown[39]) {
      theta += rotateSpeed;
    }
    // Forward
    if (keysDown[38]) {
      xS += math.sin(angle)*.2;
      yS -= math.cos(angle)*.2;
    }

    // shoot
    if (keysDown[32] && tickCount - lastShot > 25) {
      lastShot = tickCount;
      bullets.add(new Bullet(_x, _y, angle));
    }
    for (var bullet in bullets) {
      bullet.tick();
    }
    
    // Kill bullets that have just been chillen'
    bullets.retainWhere((bullet) => bullet.tickCount < MAX_BULLET_AGE);
    
    // Prevent the ship from going too fast
    if (xS > MAX_SPEED) { xS = MAX_SPEED; }
    if (xS < -MAX_SPEED) {xS = -MAX_SPEED; }
    if (yS > MAX_SPEED) { yS = MAX_SPEED; }
    if (yS < -MAX_SPEED) {yS = -MAX_SPEED; }
    
    // Update the ship position
    _x += xS;
    _y += yS;

    // Blow up?
    for (var astroid in astroids) {
      if (astroid.collide(this)) {
        loseGame = true;
      }
    }
    
    // This wraps the player.
    mirror();
    
    // Slow down slowly.
    xS *= 0.97;
    yS *= 0.97;
    
    angle += theta;
  }
  
  void render(CanvasRenderingContext2D ctx) {
    for (var bullet in bullets) {
      bullet.render(ctx);
    }
    ctx.save();
    ctx.translate(_x, _y);
    ctx.rotate(angle);
    ctx.translate(-8, -16);
    ctx.drawImageScaledFromSource(sheet, 0, 0, 8, 13, 0, 0, _width, _height);
    ctx.restore();
  }
}

class Game {
  CanvasElement _canvas;
  int width, height;
  CanvasRenderingContext2D ctx;
  List<Renderer> renderers = [];
  
  Game(CanvasElement canvas) {
    _canvas = canvas;
    width = canvas.clientWidth;
    height = canvas.clientHeight;
    Ship s = new Ship();
    tickers.add(s);
    Astroid a = new Astroid(64, 64, 3, 10.0, 10.0, 3.0, 3.0);
    astroids.add(a);
    renderers.add(s);
  }
  
  void Start() {
    ctx = _canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false; // No blur on scaled images
    window.onKeyDown.listen(onKeyDown);
    window.onKeyUp.listen(onKeyUp);
    window.animationFrame.then(animate);
  }
  
  void onKeyDown(KeyboardEvent e) {
    if (e.keyCode < keysDown.length) {
      keysDown[e.keyCode] = true;
    }
  }
  
  void onKeyUp(KeyboardEvent e) {
    if (e.keyCode < keysDown.length) {
      keysDown[e.keyCode] = false;
    }
  }
  
  int lastTime = new DateTime.now().millisecondsSinceEpoch;

  void animate(double delta) {
    int now = new DateTime.now().millisecondsSinceEpoch;
    double unprocessedFrames = 0.0;
    /*
     * Number of milliseconds that have elapsed since the last time we rendered
     * Divided by number of milliseconds per second gives us number of seconds 
     * that have elapsed since the last rendering
     * Multiplied by 60 frames/sec tell me how many frames *should* have happened.
     */
    unprocessedFrames+=(now-lastTime)*60.0/1000.0; // 60 fps
    lastTime = now;
    if (unprocessedFrames>10.0) unprocessedFrames = 10.0; 
    while (unprocessedFrames>1.0) {
      tick();
      unprocessedFrames-=1.0;
    }
    render();
   
    if (!loseGame) { 
      window.animationFrame.then(animate);
    }
  }
  
  void tick() {
    if (astroids.length == 0 && !loseGame) {
      winGame = true;
    }
    for (var astroid in astroids) {
      astroid.tick();
    }
    for (var ticker in tickers) {
      ticker.tick();
    }
  }
  
  void render() {
    clear();
    if (loseGame) {
      renderGameOver();
    } else if (winGame) {
      renderWinGame();
    } else {
      for (var astroid in astroids) {
        astroid.render(ctx);
      }
      for (var renderer in renderers) {
        renderer.render(ctx);
      }
    }
  }
  
  void renderGameOver() {
    ctx.fillText("Game Over!", 10, 20, 500);
  }
  void renderWinGame() {
    ctx.fillText("You WIN!!", 10, 20, 500);
  }
  
  void clear() {
    ctx.clearRect(0, 0, width, height);
  }
}

void main() {
  Game g = new Game(querySelector('#game'));
  keysDown.fillRange(0, keysDown.length, false);
  g.Start();
}