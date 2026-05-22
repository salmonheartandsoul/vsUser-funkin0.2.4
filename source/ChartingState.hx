package;

import Section.SwagSection;
import Song.SwagSong;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.events.Event;
import openfl.events.IOErrorEvent; // FIX: removed the two duplicate IOErrorEvent imports
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.ByteArray;

using StringTools;

class ChartingState extends MusicBeatState
{
	var _file:FileReference;

	var UI_box:FlxUITabMenu;

	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	var curSection:Int = 0;

	var bpmTxt:FlxText;

	var strumLine:FlxSprite;
	var curSong:String = 'Dadbattle';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup; // FIX: initialized in create() below

	var GRID_SIZE:Int = 40;

	var dummyArrow:FlxSprite;

	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedSustains:FlxTypedGroup<FlxSprite>;

	var gridBG:FlxSprite;
	// Vertical separator between opponent (left) and player (right) columns
	var gridSeparator:FlxSprite;

	var _song:SwagSong;

	var typingShit:FlxInputText;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic>;

	var tempBpm:Int = 0;

	var vocals:FlxSound;

	// FIX: guard flag so section auto-advance only fires once per crossing
	var _lastAutoAdvanceSection:Int = -1;

	override function create()
	{
		FlxG.mouse.visible = true;

		// FIX: bullshitUI was declared but never instantiated — would crash in generateUI()
		bullshitUI = new FlxGroup();
		add(bullshitUI);

		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 8, GRID_SIZE * 16);
		add(gridBG);

		// Separator line between opponent (cols 0-3) and player (cols 4-7)
		gridSeparator = new FlxSprite(GRID_SIZE * 4, 0).makeGraphic(2, GRID_SIZE * 16, FlxColor.fromRGB(255, 255, 255, 200));
		add(gridSeparator);

		// Column header labels — screen-fixed so they always sit above the grid
		var labelOpponent = new FlxText(0, 5, GRID_SIZE * 4, "OPPONENT", 12);
		labelOpponent.alignment = CENTER;
		labelOpponent.color = FlxColor.fromRGB(255, 120, 120);
		labelOpponent.scrollFactor.set();
		add(labelOpponent);

		var labelPlayer = new FlxText(GRID_SIZE * 4, 5, GRID_SIZE * 4, "PLAYER", 12);
		labelPlayer.alignment = CENTER;
		labelPlayer.color = FlxColor.fromRGB(120, 200, 255);
		labelPlayer.scrollFactor.set();
		add(labelPlayer);

		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedSustains = new FlxTypedGroup<FlxSprite>();

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			_song = {
				song: 'Monster',
				notes: [],
				bpm: 95,
				sections: 0,
				needsVoices: false,
				player1: 'bf',
				player2: 'dad',
				sectionLengths: [],
				speed: 1,
				validScore: false
			};
		}

		tempBpm = _song.bpm;

		addSection();

		updateGrid();

		loadSong(_song.song);
		Conductor.changeBPM(_song.bpm);

		bpmTxt = new FlxText(1000, 50, 0, "", 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(FlxG.width / 2), 4);
		add(strumLine);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'}
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(300, 400);
		UI_box.x = FlxG.width / 2;
		UI_box.y = 20;
		add(UI_box);

		addSongUI();
		addSectionUI();
		addNoteUI();

		add(curRenderedNotes);
		add(curRenderedSustains);

		super.create();
	}

	function addSongUI():Void
	{
		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";

		var labelSongName = new FlxText(10, 2, 80, "Song Name", 8);
		var UI_songTitle = new FlxUIInputText(10, 13, 70, _song.song, 8);
		typingShit = UI_songTitle;

		var check_voices = new FlxUICheckBox(10, 35, null, null, "Has voice track", 100);
		// FIX: was always hardcoded to true; now reads from the actual song data
		check_voices.checked = _song.needsVoices;
		check_voices.callback = function()
		{
			_song.needsVoices = check_voices.checked;
			trace('CHECKED!');
		};

		var saveButton:FlxButton = new FlxButton(110, 11, "Save", function()
		{
			saveLevel();
		});

		var reloadSong:FlxButton = new FlxButton(saveButton.x + saveButton.width + 10, saveButton.y, "Reload Audio", function()
		{
			loadSong(_song.song);
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 22, "Reload JSON", function()
		{
			loadJson(_song.song.toLowerCase());
		});

		var labelBPM = new FlxText(10, 58, 80, "Song BPM", 8);
		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 69, 1, 1, 1, 250, 0);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';

		var labelSpeed = new FlxText(10, 84, 80, "Song Speed", 8);
		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, 95, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';

		var characters:Array<String> = ["bf", 'dad', 'gf', 'spooky', 'monster', 'pico', 'user'];

		var labelP1 = new FlxText(10, 112, 120, "Player 1 (BF)", 8);
		var player1DropDown = new FlxUIDropDownMenu(10, 122, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
		});
		player1DropDown.selectedLabel = _song.player1;

		var labelP2 = new FlxText(140, 112, 120, "Player 2 (Opponent)", 8);
		var player2DropDown = new FlxUIDropDownMenu(140, 122, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player2 = characters[Std.parseInt(character)];
		});
		player2DropDown.selectedLabel = _song.player2;

		tab_group_song.add(labelSongName);
		tab_group_song.add(UI_songTitle);
		tab_group_song.add(check_voices);
		tab_group_song.add(saveButton);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(labelBPM);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(labelSpeed);
		tab_group_song.add(stepperSpeed);
		tab_group_song.add(labelP1);
		tab_group_song.add(player1DropDown);
		tab_group_song.add(labelP2);
		tab_group_song.add(player2DropDown);

		UI_box.addGroup(tab_group_song);
		UI_box.scrollFactor.set();

		FlxG.camera.follow(strumLine);
	}

	var stepperLength:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		var labelLength = new FlxText(10, 2, 90, "Section Length (steps)", 8);
		stepperLength = new FlxUINumericStepper(10, 13, 4, 0, 0, 999, 0);
		stepperLength.value = _song.notes[curSection].lengthInSteps;
		stepperLength.name = "section_length";

		check_mustHitSection = new FlxUICheckBox(10, 32, null, null, "Must hit section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = true;

		check_changeBPM = new FlxUICheckBox(10, 52, null, null, 'Change BPM', 100);
		check_changeBPM.name = 'check_changeBPM';

		var labelSectionBPM = new FlxText(10, 70, 90, "Override BPM", 8);
		stepperSectionBPM = new FlxUINumericStepper(10, 81, 1, Conductor.bpm, 0, 999, 0);
		stepperSectionBPM.value = Conductor.bpm;
		stepperSectionBPM.name = 'section_bpm';

		var labelCopyOffset = new FlxText(110, 70, 90, "Copy offset", 8);
		var stepperCopy:FlxUINumericStepper = new FlxUINumericStepper(110, 81, 1, 1, -999, 999, 0);

		var copyButton:FlxButton = new FlxButton(110, 99, "Copy last section", function()
		{
			copySection(Std.int(stepperCopy.value));
		});

		tab_group_section.add(labelLength);
		tab_group_section.add(stepperLength);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(labelSectionBPM);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(labelCopyOffset);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(copyButton);

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		var labelSus = new FlxText(10, 2, 180, "Sustain Length (ms)", 8);
		stepperSusLength = new FlxUINumericStepper(10, 13, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 16);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';

		// FIX: applyLength button had no callback — it now actually applies the sustain length
		var applyLength:FlxButton = new FlxButton(150, 13, 'Apply', function()
		{
			if (curSelectedNote != null)
			{
				curSelectedNote[2] = stepperSusLength.value;
				updateGrid();
			}
		});

		var labelHint = new FlxText(10, 35, 250, "Ctrl+Click to select  |  Q / E to adjust sustain", 8);
		labelHint.color = FlxColor.fromRGB(180, 180, 180);

		tab_group_note.add(labelSus);
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(applyLength);
		tab_group_note.add(labelHint);

		UI_box.addGroup(tab_group_note);
	}

	function loadSong(daSong:String):Void
	{
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
		}

		// FIX: stop and destroy the old vocals sound before creating a new one to avoid leaking
		if (vocals != null)
		{
			vocals.stop();
			FlxG.sound.list.remove(vocals, true);
			vocals = null;
		}

		FlxG.sound.playMusic('assets/music/' + daSong + "_Inst" + TitleState.soundExt, 0.6);

		// FIX: only load voices if the song actually needs them
		if (_song.needsVoices)
		{
			vocals = new FlxSound().loadEmbedded("assets/music/" + daSong + "_Voices" + TitleState.soundExt);
			FlxG.sound.list.add(vocals);
			vocals.pause();
		}
		else
		{
			// Provide a silent dummy so the rest of the code doesn't need null checks
			vocals = new FlxSound();
			FlxG.sound.list.add(vocals);
		}

		FlxG.sound.music.pause();

		FlxG.sound.music.onComplete = function()
		{
			vocals.pause();
			vocals.time = 0;
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		};
	}

	function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Must hit section':
					_song.notes[curSection].mustHitSection = check.checked;
				case 'Change BPM':
					_song.notes[curSection].changeBPM = check.checked;
					FlxG.log.add('changed bpm shit');
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			FlxG.log.add(wname);
			if (wname == 'section_length')
			{
				_song.notes[curSection].lengthInSteps = Std.int(nums.value);
				updateGrid();
			}
			else if (wname == 'song_speed')
			{
				_song.speed = nums.value;
			}
			else if (wname == 'song_bpm')
			{
				tempBpm = Std.int(nums.value);
				Conductor.changeBPM(Std.int(nums.value));
			}
			else if (wname == 'note_susLength')
			{
				// FIX: guard against null curSelectedNote before writing to it
				if (curSelectedNote != null)
				{
					curSelectedNote[2] = nums.value;
					updateGrid();
				}
			}
			else if (wname == 'section_bpm')
			{
				_song.notes[curSection].bpm = Std.int(nums.value);
				updateGrid();
			}
		}
	}

	var updatedSection:Bool = false;

	function lengthBpmBullshit():Float
	{
		if (_song.notes[curSection].changeBPM)
			return _song.notes[curSection].lengthInSteps * (_song.notes[curSection].bpm / _song.bpm);
		else
			return _song.notes[curSection].lengthInSteps;
	}

	override function update(elapsed:Float)
	{
		curStep = recalculateSteps();

		Conductor.songPosition = FlxG.sound.music.time;
		_song.song = typingShit.text;

		strumLine.y = getYfromStrum(Conductor.songPosition % (Conductor.stepCrochet * lengthBpmBullshit()));

		// FIX: was `curBeat % 4 == 0` which fired on EVERY beat divisible by 4, not just
		// when crossing into a new section. Guard with _lastAutoAdvanceSection so it only
		// triggers once per actual section boundary crossing.
		if (curStep > _song.notes[curSection].lengthInSteps * (curSection + 1) && _lastAutoAdvanceSection != curSection + 1)
		{
			_lastAutoAdvanceSection = curSection + 1;
			trace(curStep);
			trace((_song.notes[curSection].lengthInSteps) * (curSection + 1));
			trace('Section boundary crossed');

			if (_song.notes[curSection + 1] == null)
			{
				addSection();
			}

			changeSection(curSection + 1, false);
		}

		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEach(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else
						{
							trace('tryin to delete note...');
							deleteNote(note);
						}
					}
				});
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + gridBG.width
					&& FlxG.mouse.y > gridBG.y
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSection].lengthInSteps))
				{
					FlxG.log.add('added note');
					addNote();
				}
			}
		}

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSection].lengthInSteps))
		{
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT)
				dummyArrow.y = FlxG.mouse.y;
			else
				dummyArrow.y = Math.floor(FlxG.mouse.y / GRID_SIZE) * GRID_SIZE;
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			PlayState.SONG = _song;
			FlxG.sound.music.stop();
			vocals.stop();
			FlxG.switchState(new PlayState());
		}

		if (!typingShit.hasFocus)
		{
			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					vocals.pause();
				}
				else
				{
					vocals.play();
					FlxG.sound.music.play();
				}
			}

			if (FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					changeSection();
				else
					changeSection(curSection);
			}

			// Mouse wheel scrubs the strumline one step at a time
			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				FlxG.sound.music.time -= FlxG.mouse.wheel * Conductor.stepCrochet;
				FlxG.sound.music.time = Math.max(0, FlxG.sound.music.time);
				vocals.time = FlxG.sound.music.time;
			}

			if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
			{
				FlxG.sound.music.pause();
				vocals.pause();

				var daTime:Float = 700 * FlxG.elapsed;

				if (FlxG.keys.pressed.W)
				{
					FlxG.sound.music.time -= daTime;
				}
				else
					FlxG.sound.music.time += daTime;

				vocals.time = FlxG.sound.music.time;
			}

			// Q decreases sustain on selected note, E increases it, both by one step
			if (curSelectedNote != null)
			{
				if (FlxG.keys.justPressed.E)
				{
					curSelectedNote[2] += Conductor.stepCrochet;
					updateGrid();
					updateNoteUI();
				}
				if (FlxG.keys.justPressed.Q)
				{
					curSelectedNote[2] = Math.max(0, curSelectedNote[2] - Conductor.stepCrochet);
					updateGrid();
					updateNoteUI();
				}
			}
		}

		_song.bpm = tempBpm;

		var shiftThing:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			shiftThing = 4;
		if (FlxG.keys.justPressed.RIGHT)
			changeSection(curSection + shiftThing);
		if (FlxG.keys.justPressed.LEFT)
			changeSection(curSection - shiftThing);

		// FIX: removed the double-assignment `bpmTxt.text = bpmTxt.text = ...`
		bpmTxt.text = Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2))
			+ " / "
			+ Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2))
			+ "\nSection: "
			+ curSection;
		super.update(elapsed);
	}

	function recalculateSteps():Int
	{
		var steps:Int = 0;
		var timeShit:Float = 0;

		for (i in 0...curSection)
		{
			// FIX: was hardcoded to 16; now uses the section's actual lengthInSteps
			steps += _song.notes[i].lengthInSteps;

			if (_song.notes[i].changeBPM)
				timeShit += (((60 / _song.notes[i].bpm) * 1000) / 4) * _song.notes[i].lengthInSteps;
			else
				timeShit += (((60 / _song.bpm) * 1000) / 4) * _song.notes[i].lengthInSteps;
		}

		steps += Math.floor((FlxG.sound.music.time - timeShit) / Conductor.stepCrochet);
		curStep = steps;
		updateBeat();

		return curStep;
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		trace('changing section' + sec);

		if (_song.notes[sec] != null)
		{
			curSection = sec;
			// Reset the auto-advance guard whenever we manually change sections
			_lastAutoAdvanceSection = -1;

			if (updateMusic)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				// FIX: old loop called lengthBpmBullshit() every iteration but curSection
				// was already set to sec, so it always used sec's length — wrong for
				// songs with variable section lengths or per-section BPMs.
				FlxG.sound.music.time = getSectionStartTime(sec);
				vocals.time = FlxG.sound.music.time;
				updateCurStep();
			}

			// FIX: was called twice (before and after updateMusic), causing a double redraw
			updateGrid();
			updateSectionUI();
		}
	}

	function copySection(?sectionNum:Int = 1)
	{
		var daSec = FlxMath.maxInt(curSection, sectionNum);

		for (note in _song.notes[daSec - sectionNum].sectionNotes)
		{
			var strum = note[0] + Conductor.stepCrochet * (_song.notes[daSec].lengthInSteps * sectionNum);

			var copiedNote:Array<Dynamic> = [strum, note[1], note[2]];
			_song.notes[daSec].sectionNotes.push(copiedNote);
		}

		updateGrid();
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSection];

		stepperLength.value = sec.lengthInSteps;
		check_mustHitSection.checked = sec.mustHitSection;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;
	}

	function updateNoteUI():Void
	{
		// FIX: guard against null curSelectedNote before reading from it
		if (curSelectedNote != null)
			stepperSusLength.value = curSelectedNote[2];
	}

	/**
	 * Returns the absolute song time (ms) at which the given section starts,
	 * correctly accounting for variable section lengths and per-section BPMs.
	 */
	function getSectionStartTime(sec:Int):Float
	{
		var time:Float = 0;
		for (i in 0...sec)
		{
			var bpm = (_song.notes[i].changeBPM && _song.notes[i].bpm > 0) ? _song.notes[i].bpm : _song.bpm;
			var stepCrochet = ((60 / bpm) * 1000) / 4;
			time += _song.notes[i].lengthInSteps * stepCrochet;
		}
		return time;
	}

	function updateGrid():Void
	{
		while (curRenderedNotes.members.length > 0)
		{
			curRenderedNotes.remove(curRenderedNotes.members[0], true);
		}

		while (curRenderedSustains.members.length > 0)
		{
			curRenderedSustains.remove(curRenderedSustains.members[0], true);
		}

		// Resize the grid and separator to match this section's actual step count
		var rows = _song.notes[curSection].lengthInSteps;
		var newGrid = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 8, GRID_SIZE * rows);
		gridBG.pixels = newGrid.pixels;
		gridBG.updateHitbox();
		gridSeparator.makeGraphic(2, GRID_SIZE * rows, FlxColor.fromRGB(255, 255, 255, 200));

		var sectionInfo:Array<Dynamic> = _song.notes[curSection].sectionNotes;

		if (_song.notes[curSection].changeBPM && _song.notes[curSection].bpm > 0)
		{
			Conductor.changeBPM(_song.notes[curSection].bpm);
		}
		else
		{
			Conductor.changeBPM(tempBpm);
		}

		// Compute this section's start time once so each note can subtract it
		var sectionStartTime = getSectionStartTime(curSection);

		for (i in sectionInfo)
		{
			var daNoteInfo = i[1];
			var daStrumTime = i[0];
			var daSus = i[2];

			var note:Note = new Note(daStrumTime, daNoteInfo % 4);
			note.sustainLength = daSus;
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.x = Math.floor(daNoteInfo * GRID_SIZE);
			// FIX: use section-relative time so notes land on the correct grid row.
			// The old code passed the absolute timestamp, which is only correct for
			// section 0; all other sections wrapped via % gridBG.height and landed wrong.
			note.y = Math.floor(getYfromStrum(daStrumTime - sectionStartTime));

			curRenderedNotes.add(note);

			if (daSus > 0)
			{
				var sustainVis:FlxSprite = new FlxSprite(note.x + (GRID_SIZE / 2),
					note.y + GRID_SIZE).makeGraphic(8, Math.floor(FlxMath.remapToRange(daSus, 0, Conductor.stepCrochet * 16, 0, gridBG.height)));
				curRenderedSustains.add(sustainVis);
			}
		}
	}

	private function addSection(lengthInSteps:Int = 16):Void
	{
		var sec:SwagSection = {
			lengthInSteps: lengthInSteps,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			sectionNotes: [],
			typeOfSection: 0
		};

		_song.notes.push(sec);
	}

	function selectNote(note:Note):Void
	{
		var swagNum:Int = 0;

		for (i in _song.notes[curSection].sectionNotes)
		{
			// FIX: was using field access (i.strumTime / i.noteData) on a raw Array<Dynamic>
			// which always evaluates to null — must use index access like deleteNote does
			if (i[0] == note.strumTime && i[1] % 4 == note.noteData)
			{
				curSelectedNote = _song.notes[curSection].sectionNotes[swagNum];
			}

			swagNum += 1;
		}

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
		for (i in _song.notes[curSection].sectionNotes)
		{
			if (i[0] == note.strumTime && i[1] % 4 == note.noteData)
			{
				FlxG.log.add('FOUND EVIL NUMBER');
				_song.notes[curSection].sectionNotes.remove(i);
			}
		}

		updateGrid();
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote():Void
	{
		// FIX: was using hardcoded `16` — must use lengthBpmBullshit() to account for
		// sections that aren't 16 steps long and per-section BPM changes
		// FIX: use getSectionStartTime() instead of the naive curSection * stepCrochet * 16
		// so notes placed in any section have the correct absolute strum time
		var noteStrum = getStrumTime(dummyArrow.y) + getSectionStartTime(curSection);
		var noteData = Math.floor(FlxG.mouse.x / GRID_SIZE);
		var noteSus = 0;

		_song.notes[curSection].sectionNotes.push([noteStrum, noteData, noteSus]);

		curSelectedNote = _song.notes[curSection].sectionNotes[_song.notes[curSection].sectionNotes.length - 1];

		trace(noteStrum);
		trace(curSection);

		updateGrid();
		updateNoteUI();
	}

	function getStrumTime(yPos:Float):Float
	{
		// Use the section's actual step count, not a hardcoded 16
		var sectionLength = _song.notes[curSection].lengthInSteps * Conductor.stepCrochet;
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height, 0, sectionLength);
	}

	function getYfromStrum(strumTime:Float):Float
	{
		// Use the section's actual step count, not a hardcoded 16
		var sectionLength = _song.notes[curSection].lengthInSteps * Conductor.stepCrochet;
		return FlxMath.remapToRange(strumTime, 0, sectionLength, gridBG.y, gridBG.y + gridBG.height);
	}

	function calculateSectionLengths(?sec:SwagSection):Int
	{
		var daLength:Int = 0;

		for (i in _song.notes)
		{
			var swagLength = i.lengthInSteps;

			// FIX: `swagLength * 2` computed and discarded the result — changed to `*=`
			if (i.typeOfSection == Section.COPYCAT)
				swagLength *= 2;

			daLength += swagLength;

			if (sec != null && sec == i)
			{
				trace('swag loop??');
				break;
			}
		}

		return daLength;
	}

	function loadLevel():Void
	{
		trace(_song.notes);
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	function loadJson(song:String):Void
	{
		PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
		FlxG.resetState();
	}

	private function saveLevel()
	{
		var json = {
			"song": _song,
			"bpm": Conductor.bpm,
			"sections": _song.notes.length,
			'notes': _song.notes
		};

		var data:String = Json.stringify(json);

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), _song.song.toLowerCase() + ".json");
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}
}
