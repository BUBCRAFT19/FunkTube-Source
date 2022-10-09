package;

#if desktop
import Discord.DiscordClient;
#end
import WeekData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.net.curl.CURLCode;
import flixel.FlxBasic;

using StringTools;

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	private static var lastDifficultyName:String = '';

	var curDifficulty:Int = 1;

	var txtWeekTitle:Alphabet;
	var bgSprite:FlxSprite;
	var bgDefault:FlxSprite;

	// the black bars
	var topBarVis:FlxSprite;
	var topBarInvis:FlxSprite;
	var bottomBarVis:FlxSprite;
	var bottomBarInvis:FlxSprite;

	private static var curWeek:Int = 0;

	var grpWeekText:FlxTypedGroup<MenuItem>;

	var grpLocks:FlxTypedGroup<FlxSprite>;

	var difficultySelectors:FlxGroup;
	var weekSelectors:FlxGroup;
	var sprDifficulty:FlxSprite;
	var leftArrowWeek:FlxSprite;
	var rightArrowWeek:FlxSprite;
	var leftArrowDiff:FlxSprite;
	var rightArrowDiff:FlxSprite;

	var loadedWeeks:Array<WeekData> = [];

	// menu selection bools
	var weekSel:Bool = true;
	var diffSel:Bool = false;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);
		if (curWeek >= WeekData.weeksList.length)
			curWeek = 0;
		persistentUpdate = persistentDraw = true;

		bgDefault = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xFFF9CF51);
		bgDefault.screenCenter();
		add(bgDefault);

		bgSprite = new FlxSprite(0, 0);
		bgSprite.screenCenter();
		bgSprite.antialiasing = ClientPrefs.globalAntialiasing;
		add(bgSprite);

		topBarVis = new FlxSprite(0, 0).makeGraphic(FlxG.width, 120, FlxColor.BLACK);
		topBarVis.screenCenter(X);
		add(topBarVis);

		topBarInvis = new FlxSprite(topBarVis.x, topBarVis.y + 120).makeGraphic(FlxG.width, 10, FlxColor.BLACK);
		topBarInvis.screenCenter(X);
		topBarInvis.alpha = 0.5;
		add(topBarInvis);

		bottomBarVis = new FlxSprite(0, 600).makeGraphic(FlxG.width, 120, FlxColor.BLACK);
		bottomBarVis.screenCenter(X);
		add(bottomBarVis);

		bottomBarInvis = new FlxSprite(bottomBarVis.x, bottomBarVis.y - 15).makeGraphic(FlxG.width, 15, FlxColor.BLACK);
		bottomBarInvis.screenCenter(X);
		bottomBarInvis.alpha = 0.5;
		add(bottomBarInvis);

		// Does this seem like bad code to you?
		txtWeekTitle = new Alphabet(0, 10, "TestText", true);
		txtWeekTitle.setAlignmentFromString('center');
		txtWeekTitle.scaleX = 1.5;
		txtWeekTitle.scaleY = 1.5;
		txtWeekTitle.screenCenter(X);
		txtWeekTitle.x += txtWeekTitle.width / 2;
		add(txtWeekTitle);

		grpWeekText = new FlxTypedGroup<MenuItem>();
		add(grpWeekText);

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		var num:Int = 0;
		for (i in 0...WeekData.weeksList.length)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
			if (!isLocked || !weekFile.hiddenUntilUnlocked)
			{
				loadedWeeks.push(weekFile);
				WeekData.setDirectoryFromWeek(weekFile);
				var weekThing:MenuItem = new MenuItem(0, 620, WeekData.weeksList[i]);
				weekThing.screenCenter(X);
				weekThing.targetX = num;
				grpWeekText.add(weekThing);

				weekThing.antialiasing = ClientPrefs.globalAntialiasing;
				// weekThing.updateHitbox();

				// Needs an offset thingie
				if (isLocked)
				{
					var lock:FlxSprite = new FlxSprite(0, 620);
					lock.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
					lock.animation.addByPrefix('lock', 'lock');
					lock.animation.play('lock');
					lock.screenCenter(X);
					lock.antialiasing = ClientPrefs.globalAntialiasing;
					grpLocks.add(lock);
				}
				num++;
			}
		}

		WeekData.setDirectoryFromWeek(loadedWeeks[0]);

		weekSelectors = new FlxGroup();
		add(weekSelectors);

		leftArrowWeek = new FlxSprite(10, 318);
		leftArrowWeek.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		leftArrowWeek.animation.addByPrefix('idle', "arrow left");
		leftArrowWeek.animation.addByPrefix('press', "arrow push left");
		leftArrowWeek.animation.play('idle');
		leftArrowWeek.antialiasing = ClientPrefs.globalAntialiasing;
		weekSelectors.add(leftArrowWeek);

		rightArrowWeek = new FlxSprite(1224, 318);
		rightArrowWeek.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		rightArrowWeek.animation.addByPrefix('idle', 'arrow right');
		rightArrowWeek.animation.addByPrefix('press', "arrow push right", 24, false);
		rightArrowWeek.animation.play('idle');
		rightArrowWeek.antialiasing = ClientPrefs.globalAntialiasing;
		weekSelectors.add(rightArrowWeek);

		// selector split

		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		if (lastDifficultyName == '')
		{
			lastDifficultyName = CoolUtil.defaultDifficulty;
		}
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));

		sprDifficulty = new FlxSprite(0, 630);
		sprDifficulty.antialiasing = ClientPrefs.globalAntialiasing;
		sprDifficulty.screenCenter(X);
		difficultySelectors.add(sprDifficulty);

		leftArrowDiff = new FlxSprite(FlxG.width / 3, 620);
		leftArrowDiff.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		leftArrowDiff.animation.addByPrefix('idle', "arrow left");
		leftArrowDiff.animation.addByPrefix('press', "arrow push left");
		leftArrowDiff.animation.play('idle');
		leftArrowDiff.antialiasing = ClientPrefs.globalAntialiasing;
		difficultySelectors.add(leftArrowDiff);

		rightArrowDiff = new FlxSprite((FlxG.width / 3) * 2, 620);
		rightArrowDiff.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		rightArrowDiff.animation.addByPrefix('idle', 'arrow right');
		rightArrowDiff.animation.addByPrefix('press', "arrow push right", 24, false);
		rightArrowDiff.animation.play('idle');
		rightArrowDiff.antialiasing = ClientPrefs.globalAntialiasing;
		difficultySelectors.add(rightArrowDiff);

		changeWeek();
		changeDifficulty();

		super.create();
	}

	override function closeSubState()
	{
		persistentUpdate = true;
		changeWeek();
		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		if (!movedBack && !selectedWeek)
		{
			var leftP = controls.UI_LEFT_P;
			var rightP = controls.UI_RIGHT_P;
			if (weekSel)
			{
				if (leftP)
				{
					changeWeek(-1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
				else if (rightP)
				{
					changeWeek(1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}

				if (leftP || rightP)
					changeDifficulty();

				if (controls.UI_RIGHT)
					rightArrowWeek.animation.play('press')
				else
					rightArrowWeek.animation.play('idle');

				if (controls.UI_LEFT)
					leftArrowWeek.animation.play('press');
				else
					leftArrowWeek.animation.play('idle');
			}
			else if (diffSel)
			{
				if (rightP)
					changeDifficulty(1);
				else if (leftP)
					changeDifficulty(-1);

				if (controls.UI_RIGHT)
					rightArrowDiff.animation.play('press')
				else
					rightArrowDiff.animation.play('idle');

				if (controls.UI_LEFT)
					leftArrowDiff.animation.play('press');
				else
					leftArrowDiff.animation.play('idle');
			}

			if (FlxG.keys.justPressed.CONTROL)
			{
				persistentUpdate = false;
				openSubState(new GameplayChangersSubstate());
			}
			else if (controls.RESET)
			{
				persistentUpdate = false;
				openSubState(new ResetScoreSubState('', curDifficulty, '', curWeek));
				// FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			else if (controls.ACCEPT)
			{
				doDiffCheck(loadedWeeks[curWeek].fileName);
				// selectWeek();
			}
		}

		if (controls.BACK && diffSel)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			weekSel = true;
			diffSel = false;
		}
		else if (controls.BACK && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			MusicBeatState.switchState(new MainMenuState());
		}

		// bad way of doing it??
		if (weekSel)
		{
			difficultySelectors.visible = false;
			weekSelectors.visible = true;
			grpWeekText.visible = true;
		}
		else if (diffSel)
		{
			difficultySelectors.visible = true;
			weekSelectors.visible = false;
			grpWeekText.visible = false;
		}
		else if (!weekSel && !diffSel)
		{
			difficultySelectors.visible = false;
			weekSelectors.visible = false;
			grpWeekText.visible = false;
		}

		topBarInvis.setPosition(topBarVis.x, topBarVis.y + 120);
		bottomBarInvis.setPosition(bottomBarVis.x, bottomBarVis.y - 15);

		super.update(elapsed);
	}

	function doDiffCheck(name:String)
	{
		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			var leWeek:WeekData = WeekData.weeksLoaded.get(name);
			if (weekSel)
			{
				weekSel = false;
				diffSel = true;
				FlxG.sound.play(Paths.sound('confirmMenu'));
			}
			else if (diffSel)
				selectWeek();
		}
		else
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectWeek()
	{
		if (stopspamming == false)
		{
			FlxG.sound.music.stop();

			FlxG.sound.play(Paths.sound('confirmMenu'));

			stopspamming = true;
		}

		// move tweens
		FlxTween.tween(topBarVis, {x: -FlxG.width}, 1.5, {ease: FlxEase.circInOut});
		FlxTween.tween(bottomBarVis, {x: FlxG.width}, 1.5, {ease: FlxEase.circInOut});

		// alpha tweens
		// couldn't actually get these to tween alpha, so this is the alternative :(
		txtWeekTitle.visible = false;
		weekSel = false;
		diffSel = false;

		// We can't use Dynamic Array .copy() because that crashes HTML5, here's a workaround.
		var songArray:Array<String> = [];
		var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
		for (i in 0...leWeek.length)
		{
			songArray.push(leWeek[i][0]);
		}

		// Nevermind that's stupid lmao
		PlayState.storyPlaylist = songArray;
		PlayState.isStoryMode = true;
		selectedWeek = true;

		var diffic = CoolUtil.getDifficultyFilePath(curDifficulty);
		if (diffic == null)
			diffic = '';

		PlayState.storyDifficulty = curDifficulty;

		PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
		PlayState.campaignScore = 0;
		PlayState.campaignMisses = 0;
		new FlxTimer().start(2, function(tmr:FlxTimer)
		{
			LoadingState.loadAndSwitchState(new PlayState(), true);
			FreeplayState.destroyFreeplayVocals();
		});
	}

	var tweenDifficulty:FlxTween;

	function changeDifficulty(change:Int = 0):Void
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = CoolUtil.difficulties.length - 1;
		if (curDifficulty >= CoolUtil.difficulties.length)
			curDifficulty = 0;

		WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

		var diff:String = CoolUtil.difficulties[curDifficulty];
		var newImage:FlxGraphic = Paths.image('menudifficulties/' + Paths.formatToSongPath(diff));
		// trace(Paths.currentModDirectory + ', menudifficulties/' + Paths.formatToSongPath(diff));

		if (sprDifficulty.graphic != newImage)
		{
			sprDifficulty.loadGraphic(newImage);
			sprDifficulty.screenCenter(X);
			sprDifficulty.y = 615;
			sprDifficulty.alpha = 0;

			// this is definitely excessive, lol. Sorry
			leftArrowDiff.x = (sprDifficulty.x - leftArrowDiff.width) - 20;
			rightArrowDiff.x = (sprDifficulty.x + sprDifficulty.width) + 20;

			if (tweenDifficulty != null)
				tweenDifficulty.cancel();
			tweenDifficulty = FlxTween.tween(sprDifficulty, {y: 630, alpha: 1}, 0.07, {
				onComplete: function(twn:FlxTween)
				{
					tweenDifficulty = null;
				}
			});
		}
		lastDifficultyName = diff;
	}

	function changeWeek(change:Int = 0):Void
	{
		curWeek += change;

		if (curWeek >= loadedWeeks.length)
			curWeek = 0;
		if (curWeek < 0)
			curWeek = loadedWeeks.length - 1;

		var leWeek:WeekData = loadedWeeks[curWeek];
		WeekData.setDirectoryFromWeek(leWeek);

		var leName:String = leWeek.storyName;
		txtWeekTitle.text = leName.toUpperCase();

		var bullShit:Int = 0;

		var unlocked:Bool = !weekIsLocked(leWeek.fileName);
		for (item in grpWeekText.members)
		{
			item.targetX = bullShit - curWeek;
			if (item.targetX == Std.int(0) && unlocked)
			{
				item.visible = true;
			}
			else if (item.targetX == Std.int(0) && !unlocked)
			{
				item.visible = true;
				item.alpha = 0.2;
			}
			else
			{
				item.visible = false;
			}
			grpLocks.forEach(function(lock:FlxSprite)
			{
				lock.visible = !unlocked;
			});
			bullShit++;
		}

		bgSprite.visible = true;
		var assetName:String = leWeek.weekBackground;
		if (assetName == null || assetName.length < 1)
		{
			bgSprite.visible = false;
		}
		else
		{
			bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
			bgSprite.setGraphicSize(FlxG.width, FlxG.height);
			bgSprite.screenCenter();
		}
		bgDefault.screenCenter();
		PlayState.storyWeek = curWeek;

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		var diffStr:String = WeekData.getCurrentWeek().difficulties;
		if (diffStr != null)
			diffStr = diffStr.trim(); // Fuck you HTML5
		difficultySelectors.visible = unlocked;

		if (diffStr != null && diffStr.length > 0)
		{
			var diffs:Array<String> = diffStr.split(',');
			var i:Int = diffs.length - 1;
			while (i > 0)
			{
				if (diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if (diffs[i].length < 1)
						diffs.remove(diffs[i]);
				}
				--i;
			}

			if (diffs.length > 0 && diffs[0].length > 0)
			{
				CoolUtil.difficulties = diffs;
			}
		}

		if (CoolUtil.difficulties.contains(CoolUtil.defaultDifficulty))
		{
			curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty)));
		}
		else
		{
			curDifficulty = 0;
		}

		var newPos:Int = CoolUtil.difficulties.indexOf(lastDifficultyName);
		// trace('Pos of ' + lastDifficultyName + ' is ' + newPos);
		if (newPos > -1)
		{
			curDifficulty = newPos;
		}
		updateText();
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore.length > 0
			&& (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	function updateText()
	{
		var leWeek:WeekData = loadedWeeks[curWeek];
		var stringThing:Array<String> = [];
		for (i in 0...leWeek.songs.length)
		{
			stringThing.push(leWeek.songs[i][0]);
		}
	}
}
