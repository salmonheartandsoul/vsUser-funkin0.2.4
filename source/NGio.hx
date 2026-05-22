package;

import flixel.util.FlxSignal;

// this is a fucking stub because this shit pisses me off 

class NGio
{
    public static var isLoggedIn:Bool = false;
    public static var scoreboardsLoaded:Bool = false;
    public static var scoreboardArray:Array<Dynamic> = [];
    public static var ngDataLoaded(default, null):FlxSignal = new FlxSignal();
    public static var ngScoresLoaded(default, null):FlxSignal = new FlxSignal();
    public static var GAME_VER:String = "v0.2.7.1";
    public static var GAME_VER_NUMS:String = "0.2.7.1";
    public static var gotOnlineVer:Bool = false;

    public static function noLogin(api:String) { trace('NGio stubbed, skipping'); }
    public function new(api:String, encKey:String, ?sessionId:String) {}
    inline static public function postScore(score:Int = 0, song:String) {}
    inline static public function logEvent(event:String) {}
    inline static public function unlockMedal(id:Int) {}
}