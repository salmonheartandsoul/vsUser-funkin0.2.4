package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import Controls;

/**
 * Keys the player cannot bind (system / meta keys we want to keep safe).
 */
private final FORBIDDEN_KEYS:Array<FlxKey> = [ESCAPE, F4, NONE];

class OptionsMenu extends MusicBeatState
{
	static inline var ITEM_Y_START:Int = 100;
	static inline var ITEM_SPACING:Int = 52;
	static inline var LABEL_X:Float = 120;
	static inline var KEY_X:Float = 520;
	static inline var HINT_X:Float = 660;

	static var CONTROL_LIST:Array<Control> = [UP, DOWN, LEFT, RIGHT, ACCEPT, BACK, PAUSE, RESET];
	static var CONTROL_NAMES:Array<String> = ["UP", "DOWN", "LEFT", "RIGHT", "ACCEPT", "BACK", "PAUSE", "RESET"];

	var curSelected:Int = 0;
	var isBinding:Bool = false; // waiting for a key press?
	var bindingSlot:Int = 0; // which slot (0 = primary, 1 = secondary)

	var nameTexts:FlxTypedGroup<FlxText>;
	var key1Texts:FlxTypedGroup<FlxText>;
	var key2Texts:FlxTypedGroup<FlxText>;
	var selector:FlxSprite;
	var statusText:FlxText;
	var overlayBG:FlxSprite;
	var overlayText:FlxText;

	override function create()
	{
		var bg:FlxSprite = new FlxSprite().loadGraphic(AssetPaths.menuDesat__png);
		bg.color = 0xFFea71fd;
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);

		var panel:FlxSprite = new FlxSprite(90, 80).makeGraphic(Std.int(FlxG.width - 180), ITEM_SPACING * CONTROL_NAMES.length + 24, 0xCC000000);
		panel.scrollFactor.set();
		add(panel);

		var title:FlxText = new FlxText(0, 30, FlxG.width, "OPTIONS — KEY BINDINGS", 28);
		title.setFormat("VCR OSD Mono", 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.scrollFactor.set();
		add(title);

		addHeader("ACTION", LABEL_X);
		addHeader("PRIMARY", KEY_X);
		addHeader("SECONDARY", HINT_X);

		selector = new FlxSprite(94, rowY(0)).makeGraphic(Std.int(FlxG.width - 188), ITEM_SPACING - 4, 0x44FFFFFF);
		selector.scrollFactor.set();
		add(selector);

		nameTexts = new FlxTypedGroup<FlxText>();
		key1Texts = new FlxTypedGroup<FlxText>();
		key2Texts = new FlxTypedGroup<FlxText>();
		add(nameTexts);
		add(key1Texts);
		add(key2Texts);

		for (i in 0...CONTROL_NAMES.length)
		{
			var y = rowY(i) + 6;

			var nameTxt = makeRowText(LABEL_X, y, CONTROL_NAMES[i], LEFT);
			nameTxt.ID = i;
			nameTexts.add(nameTxt);

			var k1Txt = makeRowText(KEY_X, y, "", LEFT);
			k1Txt.ID = i;
			key1Texts.add(k1Txt);

			var k2Txt = makeRowText(HINT_X, y, "", LEFT);
			k2Txt.ID = i;
			key2Texts.add(k2Txt);
		}

		refreshAllKeyLabels();

		statusText = new FlxText(0, FlxG.height - 36, FlxG.width, "[Z/ENTER] Bind Primary   [X] Bind Secondary   [BACKSPACE] Back", 16);
		statusText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statusText.scrollFactor.set();
		add(statusText);

		overlayBG = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xCC000000);
		overlayBG.scrollFactor.set();
		overlayBG.visible = false;
		add(overlayBG);

		overlayText = new FlxText(0, FlxG.height / 2 - 40, FlxG.width, "", 26);
		overlayText.setFormat("VCR OSD Mono", 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		overlayText.scrollFactor.set();
		overlayText.visible = false;
		add(overlayText);

		updateCursor();

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (isBinding)
		{
			handleBindingInput();
			return; // swallow all other input while waiting for a key
		}

		// navigation
		if (controls.UP_P)
		{
			FlxG.sound.play('assets/sounds/scrollMenu' + TitleState.soundExt);
			curSelected = (curSelected - 1 + CONTROL_NAMES.length) % CONTROL_NAMES.length;
			updateCursor();
		}
		if (controls.DOWN_P)
		{
			FlxG.sound.play('assets/sounds/scrollMenu' + TitleState.soundExt);
			curSelected = (curSelected + 1) % CONTROL_NAMES.length;
			updateCursor();
		}

		if (controls.ACCEPT)
			startBinding(0);

		if (FlxG.keys.justPressed.X)
			startBinding(1);

		// reset this row to defaults
		if (FlxG.keys.justPressed.R)
		{
			resetRow(curSelected);
			refreshAllKeyLabels();
			FlxG.sound.play('assets/sounds/scrollMenu' + TitleState.soundExt);
		}

		if (controls.BACK)
			FlxG.switchState(new MainMenuState());

		super.update(elapsed);
	}

	function startBinding(slot:Int):Void
	{
		bindingSlot = slot;
		isBinding = true;

		overlayBG.visible = true;
		overlayText.visible = true;
		overlayText.text = 'Rebinding  ${CONTROL_NAMES[curSelected]}  (${slot == 0 ? "PRIMARY" : "SECONDARY"})\n\nPress any key   —   ESC to cancel';
	}

	function handleBindingInput():Void
	{
		var pressed:FlxKey = FlxG.keys.firstJustPressed();
		if (pressed == FlxKey.NONE)
			return;

		if (pressed == FlxKey.ESCAPE)
		{
			cancelBinding();
			return;
		}

		// reject forbidden keys
		if (FORBIDDEN_KEYS.indexOf(pressed) != -1)
		{
			overlayText.text = 'That key cannot be used.\n\nPress any key   —   ESC to cancel';
			return;
		}

		var control = CONTROL_LIST[curSelected];
		
		var existing:Array<Int> = controls.getInputsFor(control, Keys);
		
		while (existing.length <= bindingSlot)
		{
			existing.push(FlxKey.NONE);
		}
		
		existing[bindingSlot] = pressed;
		
		// Filter out any NONE values just in case
		var newKeys:Array<FlxKey> = [];
		for (key in existing)
		{
			if (key != FlxKey.NONE && newKeys.indexOf(cast key) == -1) 
			{
				newKeys.push(cast key);
			}
		}
		
		var oldKeys = controls.getInputsFor(control, Keys).map(function(k) return cast k);
		controls.unbindKeys(control, oldKeys);
		
		controls.bindKeys(control, newKeys);

		controls.saveCustomBinds();

		refreshAllKeyLabels();
		cancelBinding();
		FlxG.sound.play('assets/sounds/confirmMenu' + TitleState.soundExt);
	}

	function cancelBinding():Void
	{
		isBinding = false;
		overlayBG.visible = false;
		overlayText.visible = false;
	}

	function resetRow(i:Int):Void
	{
		var control = CONTROL_LIST[i];
		controls.unbindKeys(control, controls.getInputsFor(control, Keys).map(function(k) return cast k));

		// re-apply Solo defaults per-control
		switch (control)
		{
			case UP:
				controls.bindKeys(UP, [W, FlxKey.UP]);
			case DOWN:
				controls.bindKeys(DOWN, [S, FlxKey.DOWN]);
			case LEFT:
				controls.bindKeys(LEFT, [A, FlxKey.LEFT]);
			case RIGHT:
				controls.bindKeys(RIGHT, [D, FlxKey.RIGHT]);
			case ACCEPT:
				controls.bindKeys(ACCEPT, [Z, SPACE, ENTER]);
			case BACK:
				controls.bindKeys(BACK, [BACKSPACE, ESCAPE]);
			case PAUSE:
				controls.bindKeys(PAUSE, [P, ENTER, ESCAPE]);
			case RESET:
				controls.bindKeys(RESET, [R]);
			default:
		}
	}

	function refreshAllKeyLabels():Void
	{
		key1Texts.forEach(function(t:FlxText)
		{
			var keys = controls.getInputsFor(CONTROL_LIST[t.ID], Keys);
			t.text = keys.length > 0 ? keyName(keys[0]) : "---";
			t.color = keys.length > 0 ? FlxColor.CYAN : 0xFFAAAAAA;
		});

		key2Texts.forEach(function(t:FlxText)
		{
			var keys = controls.getInputsFor(CONTROL_LIST[t.ID], Keys);
			t.text = keys.length > 1 ? keyName(keys[1]) : "---";
			t.color = keys.length > 1 ? FlxColor.CYAN : 0xFFAAAAAA;
		});
	}

	function updateCursor():Void
	{
		FlxTween.tween(selector, {y: rowY(curSelected)}, 0.12, {ease: FlxEase.quartOut});

		nameTexts.forEach(function(t:FlxText)
		{
			t.color = (t.ID == curSelected) ? FlxColor.YELLOW : FlxColor.WHITE;
		});
	}

	inline function rowY(i:Int):Float
		return ITEM_Y_START + i * ITEM_SPACING;

	static function keyName(keyCode:Int):String
	{
		var k:FlxKey = cast keyCode;
		#if (haxe >= "4.0.0")
		var s = FlxKey.toStringMap[k];
		#else
		var s = FlxKey.toStringMap.get(k);
		#end
		return (s != null && s != "") ? s.toUpperCase() : Std.string(keyCode);
	}

	function makeRowText(x:Float, y:Float, txt:String, align:FlxTextAlign):FlxText
	{
		var t = new FlxText(x, y, 160, txt, 20);
		t.setFormat("VCR OSD Mono", 20, FlxColor.WHITE, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.scrollFactor.set();
		return t;
	}

	function addHeader(label:String, x:Float):Void
	{
		var t = new FlxText(x, 76, 160, label, 14);
		t.setFormat("VCR OSD Mono", 14, 0xFFCCCCCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.scrollFactor.set();
		add(t);
	}
}
