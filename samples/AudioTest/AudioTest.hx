import nme.display.Sprite;
import nme.display.Shape;
import nme.display.DisplayObject;
import nme.display.SimpleButton;
import nme.display.Stage;
import nme.geom.Point;
import nme.events.Event;
import nme.events.MouseEvent;
import nme.text.TextField;
import nme.text.TextFormat;
import nme.text.TextFormatAlign;
import nme.media.Sound;
import nme.media.SoundChannel;
import nme.media.SoundTransform;
import nme.Assets;
import nme.events.SampleDataEvent;

using nme.media.SoundEngine;

class Slider extends Sprite
{
   var boxWidth:Int;
   var boxHeight:Int;
   public var max:Float;
   public var activeColour:Int;
   public var active(default,set):Bool;
   public var position(default,set):Float;
   public var onPosition:Float->Void;
   var captureStage:Stage;

   public function new(inActiveCol:Int = 0xa0ffa0)
   {
      super();
      boxWidth = boxHeight = 0;
      max = 100.0;
      position = 0.0;
      active = false;
      activeColour = inActiveCol;
      captureStage = null;
      addEventListener(MouseEvent.MOUSE_DOWN, onDown);
   }

   public function onDown(event:MouseEvent)
   {
      //if (!active) return;
      if (captureStage==null)
      {
         captureStage = stage;
         captureStage.addEventListener( MouseEvent.MOUSE_MOVE, onMove );
         captureStage.addEventListener( MouseEvent.MOUSE_UP, onUp );
      }
      position = mouseToPos(event);
      render();
      if (onPosition!=null)
         onPosition(position);
   }

   public function onMove(event:MouseEvent)
   {
      if (captureStage!=null)
      {
         position = mouseToPos(event);
         render();
         if (onPosition!=null)
            onPosition(position);
      }
   }

   public function onUp(event:MouseEvent)
   {
      if (captureStage!=null)
      {
         captureStage.removeEventListener( MouseEvent.MOUSE_MOVE, onMove );
         captureStage.removeEventListener( MouseEvent.MOUSE_UP, onUp );
         captureStage = null;
      }
   }
 

   function mouseToPos(event:MouseEvent)
   {
      if (boxWidth==0)
         return 0.0;
      var lx = globalToLocal( new Point( event.stageX, event.stageY ) ).x;
      var pos = Math.min( Math.max(0,lx)*max/boxWidth, max );
      return pos;
   }

   public function layout(inWidth:Float, inHeight:Float)
   {
      boxWidth = Std.int(inWidth);
      boxHeight = Std.int(inHeight);
      render();
   }

   public function render()
   {
      var gfx = graphics;
      gfx.clear();
      if (position!=0.0 && max>0.0)
      {
         gfx.beginFill(active ? activeColour : 0xeeeeee);
         gfx.drawRect(0,0, boxWidth*position/max, boxHeight );
         gfx.endFill();
      }
      gfx.beginFill(0xffffff,0.0);
      gfx.lineStyle(1,0xa0a0a0);
      gfx.drawRect(0.5,0.5, boxWidth, boxHeight );
   }

   public function set_active(inActive:Bool) : Bool
   {
      active = inActive;
      if (!active)
         position = 0;
      if (boxWidth>0)
         render();
      return active;
   }

   public function set_position(inPos:Float) : Float
   {
      position = Math.min(inPos,max);
      if (boxWidth>0)
         render();
      return position;
   }
}

class EngineBut extends Sprite
{
   var textField:TextField;
   var active:Bool;

   public function new(inName:String, inOnEngine:String->Void)
   {
      super();
      name = inName;
      textField = new TextField();
      textField.text = inName;
      textField.mouseEnabled = false;
      textField.text = inName;
      var s = AudioTest.getScale();
      textField.width = Std.int( s*100 );
      textField.height = Std.int( s*32 );
      active = false;

      addChild(textField);

      addEventListener( MouseEvent.CLICK, function(_) if (!active) inOnEngine(inName) );
   }
   public function setEngine(inName:String)
   {
      var s = AudioTest.getScale();
      var fmt = new TextFormat();
      fmt.align = TextFormatAlign.CENTER;
      fmt.font = "_sans";
      fmt.size = 16 * s;
 
      if (inName==null)
      {
         trace("Unknown sound engine");
         inName = "?";
      }


      if (inName.substr(0,name.length)==name)
      {
         active = true;
         textField.border = false;
         textField.background = true;
         textField.backgroundColor = 0xa0a0ff;
         fmt.color = 0xffffff;
      }
      else
      {
         active = false;
         textField.background = false;
         textField.borderColor = 0x0000ff;
         textField.border = true;
         fmt.color = 0xa0a0a0;
      }
      textField.setTextFormat(fmt);
   }
}


class AudioPageBase extends Sprite
{
   var soundChannel:SoundChannel;
   var play:SimpleButton;
   var stop:SimpleButton;
   var panLabel:TextField;
   var panSlider:Slider;
   var volumeLabel:TextField;
   var volumeSlider:Slider;
   public function layout(inWidth:Float, inHeight:Float) { }

   public function new(inName:String)
   {
      super();
      name = inName;


      play = new SimpleButton( createPlay("up"), createPlay("over"), createPlay("down"), createPlay("up") );
      var s = AudioTest.getScale();
      addChild(play);

      stop = new SimpleButton( createStop("up"), createStop("over"), createStop("down"), createStop("up") );
      addChild(stop);
      stop.addEventListener(MouseEvent.CLICK, function(_) onStop() );
   
      var fmt = new TextFormat();
      fmt.color = 0xa0a0a0;
      fmt.font = "_sans";
      fmt.size = 10 * s;
      fmt.align = TextFormatAlign.RIGHT;



      panLabel = new TextField();
      fmt.size = 16*s;
      panLabel.defaultTextFormat = fmt;
      panLabel.text = "Pan";
      panLabel.mouseEnabled = false;
      //panLabel.border = true;
      addChild(panLabel);

      panSlider = new Slider(0xe0e0ff);
      panSlider.active = true;
      panSlider.max = 1;
      panSlider.position = 0.5;
      panSlider.onPosition = onTransform;
      addChild(panSlider);


      volumeLabel = new TextField();
      fmt.size = 16*s;
      volumeLabel.defaultTextFormat = fmt;
      volumeLabel.text = "Volume";
      volumeLabel.mouseEnabled = false;
      //panLabel.border = true;
      addChild(volumeLabel);


      volumeSlider = new Slider(0xe0e0ff);
      volumeSlider.active = true;
      volumeSlider.max = 1;
      volumeSlider.position = 1.0;
      volumeSlider.onPosition = onTransform;
      addChild(volumeSlider);



   }


   public function onStop()
   {
      if (soundChannel!=null)
      {
         soundChannel.stop();
         soundChannel = null;
      }
   }



   function createPlay(state:String)
   {
      var shape = new Shape();

      var gfx = shape.graphics;
      gfx.lineStyle(3,0xa0a0a0);
      gfx.beginFill(state=="up" ? 0xffffff :
                    state=="down" ? 0xeeeeee :
                    0xeeeeff );
 
      var s = AudioTest.getScale();
      gfx.drawCircle( 40*s,   40*s, 40*s );
      gfx.beginFill( 0xffffff);
      gfx.moveTo( (40-10)*s, (40-20)*s );
      gfx.lineTo( (40-10)*s, (40+20)*s );
      gfx.lineTo( (40+20)*s, (40)*s );
      gfx.lineTo( (40-10)*s, (40-20)*s );
      return shape;
   }


   function createStop(state:String)
   {
      var shape = new Shape();

      var gfx = shape.graphics;
      gfx.lineStyle(3,0xa0a0a0);
      gfx.beginFill(state=="up" ? 0xffffff :
                    state=="down" ? 0xeeeeee :
                    0xeeeeff );
 
      var s = AudioTest.getScale();
      gfx.drawCircle( 40*s,   40*s, 40*s );

      gfx.beginFill( 0xffffff);
      gfx.drawRect( (40-15)*s, (40-15)*s, 30*s, 30*s );
      return shape;
   }


   function onTransform(_)
   {
      if (soundChannel!=null)
         soundChannel.soundTransform = getTransform();
   }

   public function getTransform()
   {
      var transform = new SoundTransform();
      transform.pan = (panSlider.position -0.5) * 2.0;
      transform.volume = volumeSlider.position;
      return transform;
   }


}




class AudioPage extends AudioPageBase
{
   var asset:String;
   var slider:Slider;
   var durationText:TextField;
   var sound:Sound;
   var listening:Bool;
   var loopLabel:TextField;
   var loops:TextField;
   var loopButs:Array<DisplayObject> = [];
   var engineButs : Array<EngineBut> = [];
   var forceMusic:Bool;

   public function new(inAsset:String)
   { 
      super(inAsset);
      asset = inAsset;
      forceMusic = inAsset.indexOf("Music")>=0;


      listening = false;

      var s = AudioTest.getScale();

      for(engine in SoundEngine.getAvailableEngines())
      {
         var e = new EngineBut(engine, setEngine);
         addChild(e);
         engineButs.push(e);
      }


      slider = new Slider();
      slider.onPosition = onPosition;
      addChild(slider);

      play.addEventListener(MouseEvent.CLICK, function(_) onPlay(slider.position) );

      durationText = new TextField();
      var fmt = new TextFormat();
      fmt.color = 0xa0a0a0;
      fmt.font = "_sans";
      fmt.size = 10 * s;
      fmt.align = TextFormatAlign.RIGHT;
      durationText.defaultTextFormat = fmt;
      durationText.mouseEnabled = false;
      addChild(durationText);

      loopLabel = new TextField();
      fmt.size = 16*s;
      loopLabel.defaultTextFormat = fmt;
      loopLabel.text = "Loops";
      loopLabel.mouseEnabled = false;
      //loopLabel.border = true;
      addChild(loopLabel);


      loops = new TextField();
      fmt.align = TextFormatAlign.LEFT;
      fmt.color = 0x000000;
      loops.defaultTextFormat = fmt;
      loops.text = "0";
      loops.mouseEnabled = false;
      //loops.border = true;
      addChild(loops);

      for(i in 0...3)
      {
         var but = createLoopBut(i);
         addChild(but);
         loopButs.push(but);
      }

      setEngine(null);
  }

  

  public function setEngine(inEngine:String)
  {
      // Don't cache - allows us to change internals
      try
      {
         sound = Assets.getSound(asset, false, forceMusic, inEngine);
      }
      catch(e:Dynamic)
      {
         sound = null;
      }
      trace("Request " + asset + " engine " + inEngine + " got " + (sound==null ? "null" : sound.getEngine()) );

      var engine = inEngine;
      if (sound==null)
         durationText.text = "Error - no sound";
      else
      {
         durationText.text = Std.int(sound.length*0.1)/100 + "s";
         slider.max = sound.length*0.001;
         engine = sound.getEngine();
      }
      for(e in engineButs)
         e.setEngine(engine);
   }


   function setLoops(inLoops:Int)
   {
      if (inLoops==0)
         loops.text = "-1";
      else
      {
         var val = Std.parseInt(loops.text) + inLoops;
         if (val<-1)
            val = -1;
         loops.text = "" + val;
      }
   }

   function createLoopBut(idx:Int)
   {
      var sprite = new Sprite();
      var s = AudioTest.getScale();
      var gfx = sprite.graphics;
      gfx.lineStyle(1, 0x3030ff);
      gfx.beginFill(0xffffff);
      gfx.drawRoundRect(0,0, 24*s, 24*s, 4*s, 4*s );
      gfx.endFill();
      var c = Std.int( 12*s );
      var l = Std.int( 4*s );
      var inf = 4*s;

      gfx.lineStyle(idx<2 ? 3*s : 2*s, 0x3030ff);
      switch(idx)
      {
         case 0:
            gfx.moveTo(c-l, c);
            gfx.lineTo(c+l, c);
            sprite.addEventListener( MouseEvent.CLICK, function(_) setLoops(-1) );
         case 1:
            gfx.moveTo(c-l,  c);
            gfx.lineTo(c+l, c);
            gfx.moveTo(c, c-l);
            gfx.lineTo(c, c+l);
            sprite.addEventListener( MouseEvent.CLICK, function(_) setLoops(1) );
         default:
            gfx.drawCircle(c-inf, c, inf+0.5);
            gfx.drawCircle(c+inf, c, inf+0.5);
            sprite.addEventListener( MouseEvent.CLICK, function(_) setLoops(0) );
      }
      return sprite;
   }

   function onPosition(inPosition:Float)
   {
      if (soundChannel!=null)
         onPlay(inPosition);
   }



   public function onPlay(inSeek:Float)
   {
      if (soundChannel!=null)
      {
         soundChannel.stop();
         soundChannel = null;
      }

      if (sound!=null)
      {
         var extra = Std.parseInt( loops.text );
         #if flash
         if (extra<0)
            extra = 0x7fffffff;
         #end
         soundChannel = sound.play(inSeek*1000.0, extra, getTransform());
         if (soundChannel!=null)
         {
            var ch = soundChannel;
            soundChannel.addEventListener( Event.SOUND_COMPLETE, function(_) onComplete(ch) );
            if (!listening)
            {
               listening = true;
               slider.active = true;
               addEventListener( Event.ENTER_FRAME, onUpdate );
            }
         }
      }
   }

   public function onUpdate(_)
   {
      if (soundChannel!=null)
      {
         var pos = soundChannel.position;
         slider.position = pos*0.001;
      }
   }

   public function onComplete(inChannel:SoundChannel)
   {
      if (inChannel==soundChannel)
      {
         removeEventListener( Event.ENTER_FRAME, onUpdate );
         slider.active = false;
         listening = false;
         soundChannel = null;
      }
   }



   override public function layout(inWidth:Float, inHeight:Float)
   {
      var s = AudioTest.getScale();
      var y0 = Std.int(40*s);
      var engineW = 0.0;
      for(e in engineButs)
         engineW += e.width;
      engineW += (engineButs.length-1) + 10*s;
      var x0 = Std.int( (inWidth-engineW) / 2 );
      for(e in engineButs)
      {
         e.x = x0;
         e.y = Std.int(10*s);
         x0 += Std.int( 10*s + e.width );
      }
      

      play.y = y0+Std.int(20*s);
      play.x = Std.int(10*s);
      stop.y = y0+Std.int(20*s);
      stop.x = Std.int(100*s);

      loopLabel.width= panLabel.width = volumeLabel.width = Std.int(100*s);
      loopLabel.height= panLabel.height = volumeLabel.height = Std.int(25*s);
      loopLabel.x = Std.int(160*s);
      loopLabel.y = y0+Std.int(24*s);

      panLabel.x = loopLabel.x;
      panLabel.y = loopLabel.y + loopLabel.height;

      panSlider.x = panLabel.x + panLabel.width + 4;
      var y = panLabel.y;
      var h = panLabel.height;
      panSlider.y = y + Std.int( (h - 20*s) * 0.5);
      panSlider.layout( Std.int(180*s), Std.int(20*s) );

      volumeLabel.x = panLabel.x;
      volumeLabel.y = panLabel.y + panLabel.height;

      volumeSlider.x = volumeLabel.x + volumeLabel.width + 4;
      var y = volumeLabel.y;
      var h = volumeLabel.height;
      volumeSlider.y = y + Std.int( (h - 20*s) * 0.5);
      volumeSlider.layout( Std.int(180*s), Std.int(20*s) );

      loops.width= Std.int(50*s);
      loops.height= Std.int(25*s);
      loops.x = Std.int(300*s);
      loops.y = y0+Std.int(24*s);

      var x = loops.x + loops.width;
      var y = loops.y;
      var h = loops.height;
      for(but in loopButs)
      {
         but.x = x;
         x+=Std.int(but.width) + 4;
         but.y = Std.int( y + (h-but.height)*0.5 );
      }

      slider.x = Std.int(10*s);
      slider.y = y0+Std.int(120*s);
      slider.layout( inWidth - s*20, s*20 );

      durationText.x = slider.x;
      durationText.y = slider.y - durationText.textHeight - 5*s;
      durationText.width = inWidth-s*20;
      durationText.height = s*20;
   }
}

class Key extends Sprite
{
   public function new(inWidth, inHeight, inCol0, inCol1, inKey:Int, inOnKey)
   {
      super();
      render(inWidth, inHeight, inCol0);
      addEventListener(MouseEvent.MOUSE_DOWN, function(_) {
         render(inWidth, inHeight, inCol1);
         inOnKey(inKey, true);
      });
      addEventListener(MouseEvent.MOUSE_UP, function(_) {
         render(inWidth, inHeight, inCol0);
         inOnKey(inKey, false);
      });
   }

   function render(inWidth, inHeight, inCol)
   {
      var gfx = graphics;
      gfx.clear();
      gfx.lineStyle(1,0x000000);
      gfx.beginFill(inCol);
      gfx.drawRect(0.5,0.5,inWidth,inHeight);
   }
}

class Keyboard extends Sprite
{
   static var octave = [ 440.000, 466.164, 493.883, 523.251, 554.365,
                     587.330, 622.254, 659.255, 698.456, 739.989, 783.991, 830.609 ];
   static var isWhite = [ true, false, true, true, false, true, false, true, true,
                      false, true, false ];



   public function new(inWidth:Float, inHeight:Float, s:Float, inOnKey:Int->Bool->Void)
   {
      super();
      var gfx = graphics;

      var k0 = 21;
      var k1 = 53;
      var x = 0;
      var w = Std.int(30*s);
      gfx.lineStyle(1,0x000000);
      gfx.beginFill(0xffffff);

      for(k in k0...k1)
      {
         var base = (k-49+120)%12;
         if (isWhite[base])
         {
            var key = new Key(w,200*s, 0xffffff, 0xe0e0ff, k, inOnKey);
            key.x = x;
            addChildAt(key,0);
            x += w;
         }
         else
         {
            var key = new Key(w*0.5,80*s, 0x000000, 0x000080, k, inOnKey);
            key.x = x-w*0.25;
            addChild(key);
         }
      }
   }

    public static function keyFrequency(k:Int)
    {
       var base = (k-49+120)%12;
       var freq = octave[base];
       while(k<49)
       {
          freq *= 0.5;
          k += 12;
       }
       while(k>=49+12)
       {
          freq *= 2;
          k-=12;
       }
       return freq;
    }


}


class DynamicAudio extends AudioPageBase
{
   var sync:Bool;
   var keyboard:Keyboard;
   var frequency:Array<Float>;
   var wasDown:Array<Bool>;
   var isDown:Array<Bool>;
   var phase0:Float;
   var sound:Sound;
   var volLeft:Float;
   var volRight:Float;


   public function new(inName:String)
   {
      super(inName);

      frequency = [];
      isDown = [];
      wasDown = [];
      for(k in 1...89)
      {
         frequency[k] = Keyboard.keyFrequency(k)*2*Math.PI/44100;
         wasDown[k] = false;
         isDown[k] = false;
      }

      sync = name=="Sync";
      phase0 = 0;
      volLeft = 0.5;
      volRight = 0.5;

      sound = new Sound();
      sound.addEventListener( SampleDataEvent.SAMPLE_DATA, onFillData );

      play.addEventListener(MouseEvent.CLICK, function(_) onPlay() );
   }

   function onPlay()
   {
      onStop();
      soundChannel = sound.play();
   }


   override public function layout(inWidth:Float, inHeight:Float)
   {
      var s = AudioTest.getScale();
      var y0 = Std.int(40*s);

      play.y = y0+Std.int(20*s);
      play.x = Std.int(10*s);
      stop.y = y0+Std.int(20*s);
      stop.x = Std.int(100*s);

      var lx = Std.int(160*s);
      var ly = y0+Std.int(24*s);

      panLabel.x = lx;
      panLabel.y = ly;
      panLabel.width = volumeLabel.width = Std.int(100*s);
      panLabel.height = volumeLabel.height = Std.int(25*s);


      panSlider.x = panLabel.x + panLabel.width + 4;
      var y = panLabel.y;
      var h = panLabel.height;
      panSlider.y = y + Std.int( (h - 20*s) * 0.5);
      panSlider.layout( Std.int(180*s), Std.int(20*s) );
      panSlider.onPosition = setVolume;

      volumeLabel.x = panLabel.x;
      volumeLabel.y = panLabel.y + panLabel.height;

      volumeSlider.x = volumeLabel.x + volumeLabel.width + 4;
      var y = volumeLabel.y;
      var h = volumeLabel.height;
      volumeSlider.y = y + Std.int( (h - 20*s) * 0.5);
      volumeSlider.layout( Std.int(180*s), Std.int(20*s) );
      volumeSlider.onPosition = setVolume;

      if (keyboard!=null)
         removeChild(keyboard);

      var ky = Std.int(160*s);
      keyboard = new Keyboard(inWidth-play.x,inHeight-ky,s,onKey);
      addChild(keyboard);
      keyboard.x = play.x;
      keyboard.y = ky;
   }

   public function setVolume(_)
   {
      volLeft =  (1-panSlider.position) * volumeSlider.position*0.5;
      volRight =  (panSlider.position) * volumeSlider.position*0.5;
   }

   public function onKey(key:Int, state:Bool)
   {
       isDown[key] = state;
   }


   public function onFillData(dataEvent:SampleDataEvent)
   {
      var size = 2048;
      var data = dataEvent.data;

      var down = new Array<Int>();
      var finishList = new Array<Int>();
      for(k in 0...isDown.length)
         if (isDown[k])
            down.push(k);
         else if (wasDown[k])
            finishList.push(k);


      for(s in 0...size)
      {
         var total = 0.0;
         for(d in down)
         {
            if (s<100 && !wasDown[d])
               total += Math.sin((phase0 + s)*frequency[d]) * s*0.01;
            else
               total += Math.sin((phase0 + s)*frequency[d]);
         }
         if (s<100)
         {
            for(d in finishList)
               total += Math.sin((phase0 + s)*frequency[d]) * (1-s*0.01);
         }
         var left = total * volLeft;
         data.writeFloat(left<-0.999 ? -0.999 : left>0.999 ? 0.999 : left);
         var right = total * volRight;
         data.writeFloat(right<-0.999 ? -0.999 : right>0.999 ? 0.999 : right);
      }

      for(k in 0...isDown.length)
         wasDown[k] = false;
      for(d in down)
         wasDown[d] = true;

      phase0 += size;
   }
}


class AudioTest extends Sprite
{
   static var pageNames = [ "Ogg", "Ogg (Music)", "Midi", "Midi (Music)", "Mp3", "Mp3 (Music)", "Sync", "Async" ];

   var currentName:String;
   var titles:Array<TextField> = [];
   var tabs:Array<Sprite> = [];
   var pages:Array<AudioPageBase> = [];
   var currentPage:AudioPageBase;
   var textFormatBg:TextFormat;
   var textFormatFg:TextFormat;
   var textFormatDisabled:TextFormat;

   public function new()
   {
      super();

      textFormatFg = createTextFormat(0x3030ff);
      textFormatBg = createTextFormat(0x000000);
      textFormatDisabled = createTextFormat(0xa0a0a0);

      for(page in pageNames)
      {
         var tab = new Sprite();
         addChild(tab);
         tabs.push(tab);
         if (canPlay(page))
            tab.addEventListener(MouseEvent.CLICK, function(_) setTab(page) );

         var tf = new TextField();
         tf.text = page;
         tab.addChild(tf);
         titles.push(tf);
         tf.mouseEnabled = false;

         if (Assets.exists(page))
            pages.push( new AudioPage(page) );
         else
            pages.push( new DynamicAudio(page) );
      }

      stage.addEventListener( Event.RESIZE, function(_) layout() );

      setTab(pages[0].name);
   }

   public static function getScale()
      return nme.ui.Scale.getFontScale();

   function createTextFormat(inColour:Int)
   {
      var result = new TextFormat();
      result.color = inColour;
      result.font = "_sans";
      result.size = 24 * getScale();
      result.align = TextFormatAlign.RIGHT;
      return result;
   }

   function setTab(inName:String)
   {
      if (inName!=currentName)
      {
         currentName = inName;
         layout();
         if (currentPage!=null)
            removeChild(currentPage);
         currentPage = null;
         for(page in pages)
            if (page.name == currentName)
            { 
               currentPage = page;
               addChild(currentPage);
               break;
            }
         layout();
      }
   }

   function canPlay(inFormat:String)
   {
      if (Assets.exists(inFormat))
         return true;
      if (inFormat=="Sync")
         return true;
      if (inFormat=="Async")
         return #if flash false #else true #end ;
      return false;
   }

   function layout()
   {
      var w = stage.stageWidth;
      var h = stage.stageHeight;
      var scale = getScale();

      var fieldH = Std.int( 40*scale );
      var fieldW = Std.int( 175*scale );

      var gfx = graphics;
      gfx.clear();
      gfx.beginFill(0x606060);
      gfx.drawRect(0,0,fieldW,h);

      var y = 0;
      for(i in 0...tabs.length)
      {
         var page = pageNames[i];
         var tab = tabs[i];
         var tf = titles[i];
         tf.width = fieldW;
         tf.height = fieldH;

         tf.setTextFormat( !canPlay(page) ? textFormatDisabled :
                        page==currentName ? textFormatFg : textFormatBg );

         var gfx = tab.graphics;
         gfx.clear();
         gfx.beginFill( 0xffffff, page==currentName ? 1 : 0 );
         gfx.drawRect(0,0,fieldW, fieldH);
         tab.y = y;
         y+=fieldH;
      }

      if (currentPage!=null)
      {
         currentPage.x = fieldW;
         currentPage.y = 0;
         currentPage.layout(w-fieldW, h);
      }
   }
}

