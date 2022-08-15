package gamestates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.system.debug.console.Console;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import gamestates.MusicBeatState.FunkinTransitionType;
import gamestates.editors.CharacterEditorState;
import gamestates.menus.MainMenuState;
import haxe.Json;
import managers.BGMusicManager;
import objects.FunkySprite;
import objects.FunkyStage;
import objects.characters.Character;
import objects.ui.SongNote;
import objects.ui.StrumLineNote;
import openfl.media.Sound;
import rhythm.Conductor;
import rhythm.Song;
import sys.io.File;

using DillyzUtil;

typedef CountdownJson =
{
	var threeOffset:Array<Int>;
	var twoOffset:Array<Int>;
	var oneOffset:Array<Int>;
	var goOffset:Array<Int>;
}

// import managers.StateManager;
class PlayState extends MusicBeatState
{
	// stage
	private var theStage:FunkyStage;

	// characters
	private var charLeft:Character;
	private var charMid:Character;
	private var charRight:Character;

	// the song
	public static var curSong:Song;

	// song control
	private var genMusic:Bool = false;
	private var canCountdown:Bool = false;
	private var countdownStarted:Bool = false;
	private var songStarted:Bool = false;
	private var songLength:Float = 0;

	// cutscene stuff
	private var preSongCutscene:Bool = false;
	private var postSongCutscene:Bool = false;
	private var inCutscene:Bool = false;

	private var countdownSprite:FlxSprite;
	private var countdownJson:CountdownJson;

	// song stuff
	private var instData:Sound;
	private var voices:FlxSound;

	// strum note stuff
	private var strumLine:Float = 50;
	private var opponentStrums:FlxTypedSpriteGroup<StrumLineNote>;
	private var playerStrums:FlxTypedSpriteGroup<StrumLineNote>;

	public static var keyCount:Int = 4; // future support
	private static var middleScroll:Bool = true;
	private static var curSpeed:Float = 1;

	// notes
	private var displayedNotes:FlxTypedSpriteGroup<SongNote>;
	private var hiddenNotes:Array<SongNote>;

	override public function create()
	{
		super.create();
		BGMusicManager.stop();

		curSong = Song.songFromName('Bopeebo', 'Hard');
		Conductor.mapBPMChanges(curSong);
		Conductor.changeBPM(curSong.bpm);

		theStage = new FunkyStage(curSong.stage);
		add(theStage);

		FlxG.camera.zoom = theStage.camZoom;

		charMid = new Character(theStage.posGF.x, theStage.posGF.y, curSong.girlfriendYouDontHave, false, false, false);
		add(charMid);

		charLeft = new Character(theStage.posDad.x, theStage.posDad.y, curSong.dad, false, false, false);
		add(charLeft);

		charRight = new Character(theStage.posBF.x, theStage.posBF.y, curSong.boyfriend, true, true, false);
		add(charRight);

		prepareStrumLineNotes();

		// this is used for cloning
		countdownSprite = new FlxSprite();
		countdownSprite.frames = Paths.sparrowV2('ui/countdown' + curSong.countdownSuffix, 'shared');
		countdownSprite.animation.addByPrefix('Three', 'Three', 24, false, false, false);
		countdownSprite.animation.addByPrefix('Two', 'Two', 24, false, false, false);
		countdownSprite.animation.addByPrefix('One', 'One', 24, false, false, false);
		countdownSprite.animation.addByPrefix('Go', 'Go', 24, false, false, false);
		countdownSprite.animation.play('Three', true);

		if (Paths.assetExists('images/ui/countdown' + curSong.countdownSuffix, 'shared', 'json'))
			countdownJson = Json.parse(File.getContent(Paths.asset('images/ui/countdown' + curSong.countdownSuffix, 'shared', 'json')));
		else
			countdownJson = {
				threeOffset: [0, 0],
				twoOffset: [0, 0],
				oneOffset: [0, 0],
				goOffset: [0, 0]
			};

		trace(countdownJson);

		Conductor.songPosition = -5000;
		canCountdown = true;

		curSpeed = curSong.speed;

		// arrow debugging
		/*var bbruhhhhh = new FlxSprite((FlxG.width / 4) - 4, 0).makeGraphic(8, FlxG.height, FlxColor.RED);
			var bbruhhhhh2 = new FlxSprite(((FlxG.width / 4) * 3) - 4, 0).makeGraphic(8, FlxG.height, FlxColor.RED);
			add(bbruhhhhh);
			add(bbruhhhhh2);
			bbruhhhhh.cameras = bbruhhhhh2.cameras = [camHUD]; */

		displayedNotes = new FlxTypedSpriteGroup<SongNote>();
		hiddenNotes = new Array<SongNote>();

		add(displayedNotes);
		displayedNotes.cameras = [camHUD];

		regenerateSong();
		startCountdown();

		postCreate();
	}

	// this function is for future usage with songs
	public function getStrumNoteName(player:Int, index:Int)
	{
		return 'Strum Line Notes';
	}

	public function getNoteName(noteData:Int, mustHit:Bool)
	{
		return 'Scrolling Notes';
	}

	private function prepareStrumLineNotes()
	{
		opponentStrums = new FlxTypedSpriteGroup<StrumLineNote>();
		playerStrums = new FlxTypedSpriteGroup<StrumLineNote>();

		add(opponentStrums);
		add(playerStrums);
		opponentStrums.cameras = playerStrums.cameras = [camHUD];

		SongNote.resetVariables();

		var noteAnimMap:Map<String, StrumLineNoteData> = new Map<String, StrumLineNoteData>();

		for (p in 0...2)
		{
			var strumMid:Float;
			if (!middleScroll)
				strumMid = (p == 0) ? FlxG.width / 4 : FlxG.width - (FlxG.width / 4);
			else
				strumMid = (p == 0) ? FlxG.width / 4 : FlxG.width / 2;

			for (i in 0...keyCount)
			{
				var strumNoteList:FlxTypedSpriteGroup<StrumLineNote> = (p == 0) ? opponentStrums : playerStrums;

				var noteDataJson:StrumLineNoteData;

				var noteName:String = getStrumNoteName(p, i);

				if (noteAnimMap.exists(noteName))
					noteDataJson = noteAnimMap.get(noteName);
				else
				{
					noteDataJson = Paths.imageJson('ui/notes/strumline/$noteName', 'shared', {
						scale: 1,
						staticOffset: [0, 0],
						hitOffset: [-3, -3],
						pressedOffset: [13, 13]
					});
					noteAnimMap.set(noteName, noteDataJson);
				}

				// var widthBetween = SongNote.noteWidth;
				var newStrumNote:StrumLineNote = new StrumLineNote(((middleScroll && p == 0 && i >= keyCount / 2.0) ? (FlxG.width / 4) * 3 : strumMid)
					+ ((SongNote.noteWidth * SongNote.noteScaling) * (i - (keyCount / 2.0) + 0.5)),
					strumLine
					- 35, i, noteName, noteDataJson);
				strumNoteList.add(newStrumNote);
				newStrumNote.alpha = 0;

				newStrumNote.x -= ((SongNote.noteWidth * SongNote.noteScaling) / 2) + 35;

				FlxTween.tween(newStrumNote, {alpha: (middleScroll && p == 0) ? 0.5 : 1, y: strumLine}, 1.75, {ease: FlxEase.circOut, startDelay: i * 0.15});
			}
		}
	}

	private function regenerateSong()
	{
		instData = Paths.songInst(curSong.songName);
		voices = new FlxSound();
		if (curSong.needsVoices)
			voices.loadEmbedded(Paths.songVoices(curSong.songName), false, false);

		FlxG.sound.list.add(voices);

		var songNoteDataMap:Map<String, SongNoteData> = new Map<String, SongNoteData>();
		for (section in curSong.notes)
			for (notes in section.theNotes)
			{
				var isBFNote:Bool = notes.noteData >= keyCount;
				if (section.mustHitSection)
					isBFNote = !isBFNote;
				var curData:SongNoteData;
				var noteName:String = getNoteName(notes.noteData, isBFNote);
				if (songNoteDataMap.exists(noteName))
					curData = songNoteDataMap.get(noteName);
				else
				{
					curData = Paths.imageJson('ui/notes/scrolling/$noteName', 'shared', {
						scale: 1,
						scrollOffsetCyan: [0, 0],
						sustainEndCyan: [40, 0],
						sustainHoldCyan: [40, 0],
						scrollOffsetLime: [0, 0],
						sustainEndLime: [40, 0],
						sustainHoldLime: [40, 0],
						scrollOffsetPink: [0, 0],
						sustainEndPink: [40, 0],
						sustainHoldPink: [40, 0],
						scrollOffsetRed: [0, 0],
						sustainEndRed: [40, 0],
						sustainHoldRed: [40, 0]
					});
					songNoteDataMap.set(noteName, curData);
				}
				var theNote:SongNote = new SongNote(0, 0, notes.strumTime, notes.noteData % keyCount, isBFNote, notes.noteType, noteName, curData);
				displayedNotes.add(theNote);
			}

		genMusic = true;
	}

	private function startCountdown()
	{
		if (!canCountdown)
			return;

		inCutscene = countdownStarted = false;
		Conductor.songPosition = -(Conductor.crochet * 5);

		var makeCountdownSpr:(String, Bool, Array<Int>) -> Void = function(countdownAnim:String, cleanOG:Bool, offsetttt:Array<Int>)
		{
			var newCountdownSpr:FlxSprite = countdownSprite.clone();
			add(newCountdownSpr);
			newCountdownSpr.cameras = [camHUD];
			newCountdownSpr.animation.play(countdownAnim, true);
			newCountdownSpr.animation.finishCallback = function(anim:String)
			{
				remove(newCountdownSpr);
				newCountdownSpr.destroy();

				if (cleanOG)
				{
					countdownSprite.destroy();
					countdownSprite = null;
				}
			};
			newCountdownSpr.screenCenter();
			newCountdownSpr.x += offsetttt[0];
			newCountdownSpr.y += offsetttt[1];
		};

		new FlxTimer().start(Conductor.crochet / 1000, function(tmr:FlxTimer)
		{
			switch (tmr.elapsedLoops)
			{
				case 1:
					FlxG.sound.play(Paths.sound('countdown/intro3', 'shared'), 0.75);
					makeCountdownSpr('Three', false, countdownJson.threeOffset);
				case 2:
					FlxG.sound.play(Paths.sound('countdown/intro2', 'shared'), 0.75);
					makeCountdownSpr('Two', false, countdownJson.twoOffset);
				case 3:
					FlxG.sound.play(Paths.sound('countdown/intro1', 'shared'), 0.75);
					makeCountdownSpr('One', false, countdownJson.oneOffset);
				case 4:
					FlxG.sound.play(Paths.sound('countdown/introGo', 'shared'), 0.75);
					makeCountdownSpr('Go', true, countdownJson.goOffset);
				case 5:
					startSong();
			}
		}, 5);
	}

	private function startSong()
	{
		songStarted = true;

		FlxG.sound.playMusic(instData, 1, false);
		voices.play();
		FlxG.sound.music.onComplete = function()
		{
			switchState(MainMenuState, [], false, FunkinTransitionType.Black);
		};
		songLength = FlxG.sound.music.length;
	}

	var dirtyNotes:Array<SongNote> = [];

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (genMusic)
		{
			dirtyNotes.wipeArray();

			for (i in displayedNotes)
			{
				var strumNoteList:FlxTypedSpriteGroup<StrumLineNote> = !i.boyfriendNote ? opponentStrums : playerStrums;
				var strumNote:StrumLineNote = strumNoteList.members[i.noteData % strumNoteList.members.length];
				i.x = strumNote.x;
				i.y = (strumNote.y - (Conductor.songPosition - i.strumTime) * (0.45 * FlxMath.roundDecimal(curSpeed, 2)));

				if (songStarted && i.strumTime <= Conductor.songPosition)
				{
					dirtyNotes.push(i);

					var curChar:Character = i.boyfriendNote ? charRight : charLeft;
					curChar.playAnim('sing${SongNote.noteDirections[i.noteData % SongNote.noteDirections.length].toUpperCase()}', true);
					strumNote.hit();
				}
			}

			for (i in dirtyNotes)
			{
				displayedNotes.remove(i);
				i.destroy();
			}
		}

		if (FlxG.keys.justPressed.ESCAPE)
			Sys.exit(0);
		else if (FlxG.keys.justPressed.ONE)
		{
			// StateManager.load(CharacterEditorState);
			switchState(CharacterEditorState, [], false);
		}
		else if (FlxG.keys.justPressed.TWO)
		{
			// StateManager.loadAndClearMemory(CharacterEditorState);
			switchState(CharacterEditorState, [], true);
		}
		else if (FlxG.keys.justPressed.THREE)
		{
			// StateManager.loadAndClearMemory(CharacterEditorState);
			switchState(MainMenuState, [], false, FunkinTransitionType.Black);
		}

		charRight.holdingControls = (FlxG.keys.pressed.S || FlxG.keys.pressed.D || FlxG.keys.pressed.K || FlxG.keys.pressed.L);
	}

	override public function beatHit()
	{
		if (curBeat % 2 == 0)
		{
			charLeft.dance();
			charMid.dance();
			charRight.dance();
		}
	}
}
