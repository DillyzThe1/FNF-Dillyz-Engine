package gamestates.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import gamestates.MusicBeatState.FunkinTransitionType;
import managers.BGMusicManager;
import objects.FunkySprite;

using DillyzUtil;

typedef MenuButtonOffset =
{
	var parentAnim:String;
	var x:Int;
	var y:Int;
}

typedef MenuButtonJson =
{
	var posOffset:Array<Int>;
	var animOffsets:Array<MenuButtonOffset>;
}

class MenuButtonThing extends FunkySprite
{
	public var menuButtonName:String;
	public var posOffset:FlxPoint;

	public function new(menuButtonName:String, posOffset:FlxPoint)
	{
		super(0, 400);
		this.menuButtonName = menuButtonName;
		this.posOffset = posOffset;
	}
}

class MainMenuState extends MusicBeatState
{
	private var funnyBG:FlxSprite;
	private var funnyBGAlt:FlxSprite;

	private var options:Array<String> = [
		'Story Mode',
		'Freeplay',
		'Options',
		'Donate' /*,
			'Story Mode',
			'Freeplay',
			'Options',
			'Donate',
			'Story Mode',
			'Freeplay',
			'Options',
			'Donate',
			'Story Mode',
			'Freeplay',
			'Options',
			'Donate',
			'Story Mode',
			'Freeplay',
			'Options',
			'Donate' ,
				'Story Mode', 'Freeplay', 'Options', 'Donate',
				'Story Mode', 'Freeplay', 'Options', 'Donate',
				'Story Mode', 'Freeplay', 'Options', 'Donate',
				'Story Mode', 'Freeplay', 'Options', 'Donate' */];
	private var optionDisplay:Array<MenuButtonThing>;
	private var curIndex:Int;

	public function menuButtonJsonDefault():MenuButtonJson
	{
		return {
			posOffset: [0, 0],
			animOffsets: [{parentAnim: "static", x: 0, y: 0}, {parentAnim: "hover", x: 0, y: 0}]
		};
	}

	override public function create()
	{
		super.create();
		BGMusicManager.play('freakyMenu', 102);

		funnyBG = new FlxSprite().loadGraphic(Paths.png('menus/menuBG_yellow'));
		funnyBG.antialiasing = true;
		// funnyBG.color = FlxColor.fromRGB(253, 232, 113, 255);
		add(funnyBG);

		funnyBGAlt = new FlxSprite().loadGraphic(Paths.png('menus/menuBG_magenta'));
		funnyBGAlt.antialiasing = true;
		funnyBGAlt.visible = false;
		// funnyBG.color = FlxColor.fromRGB(253, 232, 113, 255);
		add(funnyBGAlt);

		curCamZoom = 1.0075;

		optionDisplay = new Array<MenuButtonThing>();
		// add(optionDisplay);

		for (i in 0...options.length)
		{
			var optionJson:MenuButtonJson = menuButtonJsonDefault();
			optionJson = Paths.menuButtonJson(options[i], optionJson);
			// trace(optionJson);
			var newMenuOption:MenuButtonThing = new MenuButtonThing(options[i], new FlxPoint(optionJson.posOffset[0], optionJson.posOffset[1]));
			newMenuOption.frames = Paths.sparrowV2('menus/main menu buttons/${options[i]}', null);
			newMenuOption.animation.addByPrefix('static', '${options[i]} Static0', 24, true, false, false);
			newMenuOption.animation.addByPrefix('hover', '${options[i]} Hover0', 24, true, false, false);
			for (i in optionJson.animOffsets)
				newMenuOption.animOffsets.set(i.parentAnim, new FlxPoint(i.x, i.y));
			// trace(optionJson.animOffsets);
			// trace(newMenuOption.animOffsets);
			newMenuOption.playAnim(i == 0 ? 'hover' : 'static', true);
			add(newMenuOption);
			optionDisplay.push(newMenuOption);
			newMenuOption.antialiasing = true;

			newMenuOption.x = ((FlxG.width / 2) - (newMenuOption.width / 2)) + newMenuOption.posOffset.x + 90;
		}

		curIndex = 0;
		changeSelection();

		postCreate();
	}

	public function changeSelection(?amount:Int = 0)
	{
		if (amount != 0)
		{
			curIndex += amount;
			// curIndex = curIndex.snapInt(0, options.length - 1);
			if (curIndex < 0)
				curIndex = options.length - 1;
			else if (curIndex >= options.length)
				curIndex = 0;

			FlxG.sound.play(Paths.sound('menus/scrollMenu', null));
		}

		for (i in 0...options.length)
		{
			var curOption:MenuButtonThing = optionDisplay[i];
			var intendedAnim:String = (curIndex == i) ? 'hover' : 'static';
			if (amount != 0 && intendedAnim != curOption.getAnim())
				curOption.playAnim(intendedAnim, true);
		}

		trace(options[curIndex]);
	}

	public var stopSpamming:Bool = false;

	override public function update(e:Float)
	{
		super.update(e);

		for (i in 0...options.length)
		{
			var curOption:MenuButtonThing = optionDisplay[i];
			var intendedMulti:Int = i;
			if (curIndex >= 2)
				intendedMulti = (i - curIndex) + 2;
			curOption.y = FlxMath.lerp(85 + (135 * intendedMulti), curOption.y - curOption.posOffset.y, e * 114) + curOption.posOffset.y;
		}

		if (stopSpamming)
			return;

		if (FlxG.keys.justPressed.ENTER)
		{
			stopSpamming = true;
			FlxG.sound.play(Paths.sound('menus/confirmMenu', null));

			FlxFlicker.flicker(funnyBGAlt, 1.1, 0.15, false);

			for (i in 0...options.length)
			{
				var curOption:MenuButtonThing = optionDisplay[i];
				if (curIndex != i)
					FlxTween.tween(curOption, {alpha: 0, "scale.x": 0.85, "scale.y": 0.85}, 0.5, {ease: FlxEase.cubeInOut});
				// curOption.alpha = 0;
			}

			new FlxTimer().start(1.5, function(t:FlxTimer)
			{
				switch (optionDisplay[curIndex].menuButtonName)
				{
					case 'Story Mode' | 'Freeplay':
						switchState(PlayState, [], false, FunkinTransitionType.Normal);
					case 'Options':
						switchState(MainMenuState, [], false, FunkinTransitionType.Black);
					case 'Donate':
						FlxG.openURL('https://ninja-muffin24.itch.io/funkin');
						switchState(MainMenuState, [], false, FunkinTransitionType.Black);
					default:
						Sys.exit(0);
				}
			}, 0);
		}
		else if (FlxG.keys.justPressed.UP)
			changeSelection(-1);
		else if (FlxG.keys.justPressed.DOWN)
			changeSelection(1);
	}

	override public function beatHit()
	{
		if (curBeat % 2 == 0)
			FlxG.camera.zoom = 1.015;
		else
			FlxG.camera.zoom = 1;
	}
}