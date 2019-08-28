package nme.text;
#if (!flash)

/*@:enum
abstract TextFormatAlign(String) from String to String
{
   var LEFT = "left";
   var RIGHT = "right";
   var CENTER = "center";
   var JUSTIFY = "justify";
}*/

class TextFormatAlign 
{
	public static inline var LEFT = "left";
	public static inline var RIGHT = "right";
	public static inline var CENTER = "center";
	public static inline var JUSTIFY = "justify";
	
	public static inline var START = "left";
	public static inline var END = "right";
}

#else
typedef TextFormatAlign = flash.text.TextFormatAlign;
#end
