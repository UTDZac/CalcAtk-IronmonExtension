local function CalcAtk()
	local self = {}
	-- Define descriptive attributes of the custom extension that are displayed on the Tracker settings
	self.version = "0.3"
	self.name = "Attacking Damage Calc."
	self.author = "UTDZac"
	self.description = "Estimate an enemy Pokémon's attacking stat using a reverse damage formula calculation."
	self.github = "UTDZac/CalcAtk-IronmonExtension" -- Not release, not public, DO NOT SHARE
	self.url = string.format("https://github.com/%s", self.github)

	-- Screen "classes"
	local CalcAtkScreen = {}

	local MIN_STAT, MAX_STAT = 0, 9999
	-- Returns two values, the first is the low-roll stat (85/100) and the second is the high-roll stat (100/100)
	local function calcLowHighStat()
		local B = CalcAtkScreen.Buttons

		-- Get all known values for the formula
		local level = B.ValuePokemonLevel.value
		local damagetaken = B.ValueDamageTaken.value
		local defense = B.ValuePokemonDefense.value
		defense = defense == 0 and 1 or defense -- Avoid divide-by-zero
		local power = B.ValueMovePower.value
		power = power == 0 and 1 or power -- Avoid divide-by-zero

		local mType = B.ValueMoveEffectiveness.value
		mType = mType == 0 and 1 or mType -- Avoid divide-by-zero
		local mOther = B.ValueOtherMultiplier.value
		mOther = mOther == 0 and 1 or mOther -- Avoid divide-by-zero

		local mSTAB = B.CheckboxStab.toggleState and 1.5 or 1
		local mCritical = B.CheckboxCrit.toggleState and 2.0 or 1
		local mWeather = 1
		if B.CheckboxWeather.state == 1 then
			mWeather = 1.5
		elseif B.CheckboxWeather.state == 2 then
			mWeather = 0.5
		end
		local mBurn = B.CheckboxBurn.toggleState and 0.5 or 1
		local mScreen = B.CheckboxScreenReflect.toggleState and 0.5 or 1

		local function formuoli(attackGuess)
			-- In general, anytime division occurs, it needs to be "integer division", chopping off the decimals (aka. math.floor())
			local part1 = math.floor(math.floor((2 * level / 5 + 2) * power * (attackGuess / defense)) / 50)
			local part2 = part1 * mBurn * mScreen * mWeather + 2
			local part3 = part2 * mCritical * mSTAB * mType * mOther
			local lo = math.floor(part3 * 85 / 100)
			local hi = math.floor(part3 * 100 / 100)
			return lo, hi
		end

		local outputLow = MAX_STAT
		local outputHi = MIN_STAT
		-- Arbitrarily using [1-255] as attack stat guesses
		for attackStat = 1, 255, 1 do
			local lo, hi = formuoli(attackStat)
			-- Only consider this attack stat guess if the lo-hi damage boundaries can include the actual damage taken
			if damagetaken >= lo and damagetaken <= hi then
				if attackStat < outputLow then
					outputLow = attackStat
				end
				if attackStat > outputHi then
					outputHi = attackStat
				end
			end
		end

		CalcAtkScreen.Buttons.LabelConfidence:checkAccuracyOfCalc(outputLow, outputHi)

		return outputLow, outputHi

		-- The old method that is mathimatically correct but doesn't work well due to integer division (see note above)
		-- for i, mRandom in ipairs(randomsLowThenHigh) do
		-- 	-- The Secret Formula @ https://bulbapedia.bulbagarden.net/wiki/Damage#Generation_III
		-- 	local headExpression = math.floor(2 * level / 5 + 2) * power / defense / 50
		-- 	local midExpression = mBurn * mScreen * mWeather
		-- 	local tailExpression = mCritical * mSTAB * mType * mOther * (mRandom / 100)

		-- 	-- Try and estimate the offensive stat by working backwards
		-- 	local result = damagetaken / tailExpression
		-- 	result = result - 2
		-- 	result = result / midExpression
		-- 	result = result / math.floor(headExpression)

		-- 	statOutputs[i] = math.floor(result)
		-- end
		-- Uncomment to have each of the above values outputed to the Lua Console for debugging
		-- Utils.printDebug("damagetaken:%s, crit:%s, stab:%s, eff:%s, other:%s, def:%s, burn:%s, screen:%s, weather:%s, power:%s, level:%s",
		--                   damagetaken,    mCrit,   mStab,   mEff,   mOther,   def,    mBurn,   mScreen,   mWeather,   power,    level)

		-- return statOutputs[1], statOutputs[2]
	end

	-- Other internal stuff, not involved with the calculations
	local lastV = { moveId = 0, damage = 0, level = 0, autoCalc = false }
	local function checkIfValuesChanged()
		local properBattleTiming = Battle.inBattle and not Battle.enemyHasAttacked and Battle.lastEnemyMoveId ~= 0
		if not properBattleTiming or not MoveData.isValid(Battle.lastEnemyMoveId) then return false end

		if lastV.moveId ~= Battle.lastEnemyMoveId then
			return true
		elseif lastV.damage ~= Battle.damageReceived then
			return true
		end
		local enemyMon = Battle.getViewedPokemon(false) or {}
		if type(enemyMon.level) == "number" and lastV.level ~= enemyMon.level then
			return true
		end
		return false
	end
	local function clearButtonValues()
		for _, button in pairs(CalcAtkScreen.Buttons or {}) do
			if type(button.reset) == "function" then
				button:reset()
			end
		end
	end
	--- @return number power, string type
	local function getMovePowerAndType(move, ownMon, enemyMon)
		local movePower = move.power or MoveData.BlankMove.power
		local moveType = move.type or MoveData.BlankMove.type
		-- 311 = Weather Ball
		if move.id == 311 then
			moveType, movePower = Utils.calculateWeatherBall(moveType, movePower)
		-- 67 = Low Kick
		elseif move.id == 67 and PokemonData.isValid(ownMon.pokemonID) then
			local targetWeight = ownMon.weight or PokemonData.Pokemon[ownMon.pokemonID].weight or 0
			movePower = Utils.calculateWeightBasedDamage(movePower, targetWeight)
		-- 284 = Eruption, 323 = Water Spout
		elseif (move.id == 284 or move.id == 323) and enemyMon.curHP == enemyMon.stats.hp then
			movePower = "150"
		end
		return tonumber(movePower) or 0, moveType
	end
	local function getWeatherBoostState(move)
		local moveType = move.type or MoveData.BlankMove.type
		if moveType ~= PokemonData.Types.WATER and moveType ~= PokemonData.Types.FIRE then
			return 0 -- Default state, no weather bonus
		end
		local weatherIds = { [1] = "Rain", [5] = "Rain", [32] = "Harsh sunlight", [96] = "Harsh sunlight", }
		local battleWeather = Memory.readword(GameSettings.gBattleWeather)
		local currentWeather = weatherIds[battleWeather]
		if currentWeather == "Rain" then
			if moveType == PokemonData.Types.WATER then
				return 1 -- Boosted
			elseif moveType == PokemonData.Types.FIRE then
				return 2 -- Halved
			end
		elseif currentWeather == "Harsh sunlight" then
			if moveType == PokemonData.Types.FIRE then
				return 1 -- Boosted
			elseif moveType == PokemonData.Types.WATER then
				return 2 -- Halved
			end
		end
		return 0
	end
	-- Attempt to pull as many damage calculation values from the active Pokémon, types, and move used
	local function autoApplyValues()
		clearButtonValues()
		local B = CalcAtkScreen.Buttons
		local move = MoveData.Moves[Battle.lastEnemyMoveId or false]
		local ownMon = Battle.getViewedPokemon(true) or {}
		local enemyMon = Battle.getViewedPokemon(false) or {}
		if move then
			B.ValueDamageTaken.value = Battle.damageReceived or 0
			local movePower, moveType = getMovePowerAndType(move, ownMon, enemyMon)
			B.ValueMovePower.value = movePower
			local ownTypes = Program.getPokemonTypes(true, Battle.isViewingLeft)
			B.ValueMoveEffectiveness.value = Utils.netEffectiveness(move, moveType, ownTypes)
			local enemyTypes = Program.getPokemonTypes(false, Battle.isViewingLeft)
			B.CheckboxStab.toggleState = (moveType == enemyTypes[1] or moveType == enemyTypes[2])

			local isMovePhysical = MoveData.TypeToCategory[moveType] == MoveData.Categories.PHYSICAL
			if PokemonData.isValid(ownMon.pokemonID) then
				if isMovePhysical then
					B.ValuePokemonDefense.value = ownMon.stats.def or 0
				else
					B.ValuePokemonDefense.value = ownMon.stats.spd or 0
				end
			end
			if PokemonData.isValid(enemyMon.pokemonID) then
				B.ValuePokemonLevel.value = enemyMon.level or 0
				B.CheckboxBurn.toggleState = (isMovePhysical and enemyMon.status == MiscData.StatusType.Burn)
			end

			B.CheckboxWeather.state = getWeatherBoostState(move)
		end
		lastV.moveId = Battle.lastEnemyMoveId or 0
		lastV.damage = Battle.damageReceived or 0
		lastV.level = enemyMon.level or 0
		-- lastV.autoCalc = true -- Set elsewhere in afterValuesChanged()
	end

	local function afterValuesChanged(isAuto)
		CalcAtkScreen.Buttons.CalculatedStatOutput:recalculate(isAuto)
		CalcAtkScreen.refreshButtons()
		Program.redraw(true)
	end
	local function openEditValuePopup(button)
		local form = Utils.createBizhawkForm("Edit Value", 320, 130, 100, 50)
		forms.label(form, button:getCustomText() or "Value", 54, 20, 138, 20)
		local textBox = forms.textbox(form, button.value or 0, 45, 20, nil, 194, 18)
		forms.button(form, Resources.AllScreens.Save, function()
			button.value = tonumber(forms.gettext(textBox) or "") or button.defaultValue
			Utils.closeBizhawkForm(form)
			afterValuesChanged(false)
		end, 75, 50)
		forms.button(form, Resources.AllScreens.Cancel, function()
			Utils.closeBizhawkForm(form)
		end, 165, 50)
	end
	local function formatMultiplier(value)
		local format = {
			[0] = "0x",
			[0.25] = "1/4x",
			[0.5] = "1/2x",
			[1] = "1x",
			[2] = "2x",
			[4] = "4x",
		}
		return format[value or false] or value
	end

	-- Used to help navigate backward from the options menu, for ease of access
	local previousScreen = nil

	-----------------------
	-- CalcAtkScreen --
	-----------------------
	CalcAtkScreen.Colors = {
		text = "Default text",
		highlight = "Intermediate text",
		border = "Upper box border",
		fill = "Upper box background",
	}
	local buttonOffsetX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 105
	local buttonOffsetY = Constants.SCREEN.MARGIN + 34
	local function nextButtonY(extraOffset)
		buttonOffsetY = buttonOffsetY + Constants.SCREEN.LINESPACING + (extraOffset or 0)
		return buttonOffsetY
	end
	local function leftAlignText(button, shadowcolor)
		local x, y = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 3, button.box[2]
		local text = button:getCustomText() or button:getText() or ""
		Drawing.drawText(x, y, text, Theme.COLORS[CalcAtkScreen.Colors.text], shadowcolor)
	end
	local function btnUpdateSelf(button)
		local text = button:getText() or ""
		if text == "0" or text == "0x" then
			button.textColor = "Negative text"
		else
			button.textColor = CalcAtkScreen.Colors.highlight
		end
	end
	CalcAtkScreen.Buttons = {
		PokemonIcon = {
			type = Constants.ButtonTypes.POKEMON_ICON,
			getIconId = function(this)
				local pokemon = Battle.getViewedPokemon(false) or Tracker.getDefaultPokemon()
				return pokemon.pokemonID, SpriteData.Types.Idle
			end,
			reset = function(this) this.box[1] = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 11 end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 11, 12, 32, 32 },
			onClick = function(this)
				if this.box[1] > (Constants.SCREEN.WIDTH / 2) then
					this.box[1] = this.box[1] - 5
					Program.redraw(true)
				end
			end,
		},
		SwordIcon = {
			type = Constants.ButtonTypes.PIXELIMAGE,
			image = Constants.PixelImages.SWORD_ATTACK,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 61, Constants.SCREEN.MARGIN + 16, 13, 13 },
			onClick = function(this)
				if Battle.inBattle then
					autoApplyValues()
				end
				afterValuesChanged(true)
			end,
		},
		Clear = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function(this) return string.format("(%s)", Resources.AllScreens.Clear) end,
			textColor = CalcAtkScreen.Colors.highlight,
			box = {	Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 52, Constants.SCREEN.MARGIN + 30, 35, 11 },
			onClick = function(this)
				clearButtonValues()
				afterValuesChanged(false)
			end,
		},
		CalculatedStatOutput = {
			type = Constants.ButtonTypes.NO_BORDER,
			values = { -999, -999 },
			defaultValue = -999,
			reset = function(this) this.values = { this.defaultValue, this.defaultValue } end,
			box = {	Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 88, Constants.SCREEN.MARGIN + 14, 40, 26 },
			isVisible = function(this) return this.values[1] ~= this.defaultValue and this.values[2] ~= this.defaultValue end,
			-- updateSelf = function(this) end,
			recalculate = function(this, isAuto)
				this.values[1], this.values[2] = calcLowHighStat()
				if isAuto ~= nil then
					lastV.autoCalc = (isAuto == true)
				end
				if this.values[1] > this.values[2] then -- Simple safety check so the lower value is on top
					local swapValue = this.values[1]
					this.values[1] = this.values[2]
					this.values[2] = swapValue
				end
			end,
			draw = function(this, shadowcolor)
				local x, y = this.box[1], this.box[2]
				local w, h = this.box[3], this.box[4]
				local v1, v2 = this.values[1], this.values[2]
				-- Don't display anything if both values are incorrect
				if (v1 <= MIN_STAT or v1 >= MAX_STAT) and (v2 <= MIN_STAT or v2 >= MAX_STAT) then
					Drawing.drawText(x + 17, y + 8, Constants.HIDDEN_INFO, Theme.COLORS[CalcAtkScreen.Colors.text], shadowcolor)
					return
				end
				local v1Text = tostring(math.floor(v1))
				local v2Text = tostring(math.floor(v2))
				local x1C = Utils.getCenteredTextX(v1Text, w)
				local x2C = Utils.getCenteredTextX(v2Text, w)
				Drawing.drawText(x + 17, y + 8, "~", Theme.COLORS[CalcAtkScreen.Colors.text], shadowcolor) -- Divider
				Drawing.drawText(x + x1C, y, v1Text, Theme.COLORS["Negative text"], shadowcolor)
				Drawing.drawText(x + x2C, y + 16, v2Text, Theme.COLORS["Positive text"], shadowcolor)
			end,
			onClick = function(this)
				if Battle.inBattle then
					autoApplyValues()
				end
				afterValuesChanged(true)
			end,
		},
		ValuePokemonLevel = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function(this) return tostring(this.value) end,
			getCustomText = function() return "Enemy Pokémon Lv:" end,
			textColor = CalcAtkScreen.Colors.highlight,
			value = 0,
			defaultValue = 0,
			reset = function(this) this.value = this.defaultValue end,
			box = {	buttonOffsetX, nextButtonY(), 20, 10 },
			updateSelf = btnUpdateSelf,
			draw = leftAlignText,
			onClick = function(this) openEditValuePopup(this) end,
		},
		ValueDamageTaken = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function(this) return tostring(this.value) end,
			getCustomText = function() return "Damage:" end,
			textColor = CalcAtkScreen.Colors.highlight,
			value = 0,
			defaultValue = 0,
			reset = function(this) this.value = this.defaultValue end,
			box = {	buttonOffsetX, nextButtonY(), 20, 10 },
			updateSelf = btnUpdateSelf,
			draw = leftAlignText,
			onClick = function(this) openEditValuePopup(this) end,
		},
		ValuePokemonDefense = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function(this) return tostring(this.value) end,
			getCustomText = function() return "Your DEF/SPD:" end,
			textColor = CalcAtkScreen.Colors.highlight,
			value = 0,
			defaultValue = 0,
			reset = function(this) this.value = this.defaultValue end,
			box = {	buttonOffsetX, nextButtonY(), 20, 10 },
			updateSelf = btnUpdateSelf,
			draw = leftAlignText,
			onClick = function(this) openEditValuePopup(this) end,
		},
		ValueMovePower = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function(this) return tostring(this.value) end,
			getCustomText = function() return "Move Power:" end,
			textColor = CalcAtkScreen.Colors.highlight,
			value = 0,
			defaultValue = 0,
			reset = function(this) this.value = this.defaultValue end,
			box = {	buttonOffsetX, nextButtonY(), 20, 10 },
			updateSelf = btnUpdateSelf,
			draw = leftAlignText,
			onClick = function(this) openEditValuePopup(this) end,
		},
		ValueMoveEffectiveness = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function(this) return formatMultiplier(this.value) end,
			getCustomText = function() return "Move Effectiveness:" end,
			textColor = CalcAtkScreen.Colors.highlight,
			value = 1.0,
			defaultValue = 1.0,
			reset = function(this) this.value = this.defaultValue end,
			box = {	buttonOffsetX, nextButtonY(), 20, 10 },
			updateSelf = btnUpdateSelf,
			draw = leftAlignText,
			onClick = function(this) openEditValuePopup(this) end,
		},
		ValueOtherMultiplier = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function(this) return formatMultiplier(this.value) end,
			getCustomText = function() return "Other Multiplier(s):" end,
			textColor = CalcAtkScreen.Colors.highlight,
			value = 1.0,
			defaultValue = 1.0,
			reset = function(this) this.value = this.defaultValue end,
			box = {	buttonOffsetX, nextButtonY(), 20, 10 },
			updateSelf = btnUpdateSelf,
			draw = leftAlignText,
			onClick = function(this) openEditValuePopup(this) end,
		},
		CheckboxStab = {
			type = Constants.ButtonTypes.CHECKBOX,
			getText = function() return "STAB" end,
			toggleColor = CalcAtkScreen.Colors.highlight,
			toggleState = false,
			defaultValue = false,
			reset = function(this) this.toggleState = this.defaultValue end,
			clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, nextButtonY(3), 34, 9 },
			box = {	Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, buttonOffsetY, 8, 8 },
			onClick = function(this)
				this.toggleState = not this.toggleState
				afterValuesChanged(false)
			end,
		},
		CheckboxCrit = {
			type = Constants.ButtonTypes.CHECKBOX,
			getText = function() return "Crit" end,
			toggleColor = CalcAtkScreen.Colors.highlight,
			toggleState = false,
			defaultValue = false,
			reset = function(this) this.toggleState = this.defaultValue end,
			clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 50, buttonOffsetY, 30, 9 },
			box = {	Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 50, buttonOffsetY, 8, 8 },
			onClick = function(this)
				this.toggleState = not this.toggleState
				afterValuesChanged(false)
			end,
		},
		CheckboxWeather = {
			type = Constants.ButtonTypes.STAT_STAGE,
			getText = function(this) return Constants.STAT_STATES[this.state].text end,
			getCustomText = function() return "Weather" end,
			state = 0, -- 0=Neutral, 1=Boosted, 2=Halved
			defaultValue = 0,
			reset = function(this) this.state = this.defaultValue end,
			clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 88, buttonOffsetY, 45, 9 },
			box = {	Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 88, buttonOffsetY, 8, 8 },
			updateSelf = function(this)
				this.textColor = Constants.STAT_STATES[this.state].textColor
			end,
			draw = function(this, shadowcolor)
				local x, y = this.box[1], this.box[2]
				local w, h = this.box[3], this.box[4]
				Drawing.drawText(x + w + 1, y - 2, this:getCustomText(), Theme.COLORS[CalcAtkScreen.Colors.text], shadowcolor)
			end,
			onClick = function(this)
				this.state = (this.state + 1) % 3
				afterValuesChanged(false)
			end,
		},
		CheckboxBurn = {
			type = Constants.ButtonTypes.CHECKBOX,
			getText = function() return "Burned" end,
			toggleColor = CalcAtkScreen.Colors.highlight,
			toggleState = false,
			defaultValue = false,
			reset = function(this) this.toggleState = this.defaultValue end,
			clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, nextButtonY(2), 38, 9 },
			box = {	Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, buttonOffsetY, 8, 8 },
			onClick = function(this)
				this.toggleState = not this.toggleState
				afterValuesChanged(false)
			end,
		},
		CheckboxScreenReflect = {
			type = Constants.ButtonTypes.CHECKBOX,
			getText = function() return "Screen/Reflect" end,
			toggleColor = CalcAtkScreen.Colors.highlight,
			toggleState = false,
			defaultValue = false,
			reset = function(this) this.toggleState = this.defaultValue end,
			clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 50, buttonOffsetY, 71, 9 },
			box = {	Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 50, buttonOffsetY, 8, 8 },
			onClick = function(this)
				this.toggleState = not this.toggleState
				afterValuesChanged(false)
			end,
		},
		LabelConfidence = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function(this) return this.confidentCalc and "" or "* Low confidence calculation" end,
			textColor = CalcAtkScreen.Colors.highlight,
			confidentCalc = true,
			defaultValue = true,
			reset = function(this) this.confidentCalc = this.defaultValue end,
			isVisible = function(this) return lastV.autoCalc and not this.confidentCalc end, -- Only visible if not a confident auto-calculation
			box = {	Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 3, nextButtonY(-1), 8, 8 },
			checkAccuracyOfCalc = function(this, lowStat, highStat)
				local tolerance = 0.1 -- 10%
				local enemyMon = Battle.getViewedPokemon(false) or {}
				if not PokemonData.isValid(enemyMon.pokemonID) then
					this.confidentCalc = true -- Assume true if no enemy Pokémon to check against
					return
				elseif (lowStat <= MIN_STAT or lowStat >= MAX_STAT) and (highStat <= MIN_STAT or highStat >= MAX_STAT) then
					this.confidentCalc = true -- Assume true if the calculation fails for low or high stat
					return
				end
				lowStat = lowStat - (lowStat * tolerance)
				highStat = highStat + (highStat * tolerance)
				if enemyMon.stats.atk >= lowStat and enemyMon.stats.atk <= highStat then
					this.confidentCalc = true
				elseif enemyMon.stats.spa >= lowStat and enemyMon.stats.spa <= highStat then
					this.confidentCalc = true
				else
					this.confidentCalc = false
				end
			end,
			draw = function(this, shadowcolor)
				local statbox = CalcAtkScreen.Buttons.CalculatedStatOutput.box
				local x, y = statbox[1], statbox[2]
				local w, h = statbox[3], statbox[4]
				Drawing.drawText(x + w - 3, y + 1, "*", Theme.COLORS[CalcAtkScreen.Colors.highlight], shadowcolor)
			end,
		},
		Back = Drawing.createUIElementBackButton(function()
			Program.changeScreenView(previousScreen or SingleExtensionScreen)
			previousScreen = nil
		end, CalcAtkScreen.Colors.text),
	}
	for _, button in pairs(CalcAtkScreen.Buttons) do
		if button.textColor == nil then
			button.textColor = CalcAtkScreen.Colors.text
		end
		if button.boxColors == nil then
			button.boxColors = { CalcAtkScreen.Colors.border, CalcAtkScreen.Colors.fill }
		end
	end
	function CalcAtkScreen.refreshButtons()
		for _, button in pairs(CalcAtkScreen.Buttons or {}) do
			if type(button.updateSelf) == "function" then
				button:updateSelf()
			end
		end
	end
	function CalcAtkScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, CalcAtkScreen.Buttons or {})
	end
	function CalcAtkScreen.drawScreen()
		local canvas = {
			x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
			y = Constants.SCREEN.MARGIN + 10,
			w = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
			h = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2) - 10,
			text = Theme.COLORS[CalcAtkScreen.Colors.text],
			border = Theme.COLORS[CalcAtkScreen.Colors.border],
			fill = Theme.COLORS[CalcAtkScreen.Colors.fill],
			shadow = Utils.calcShadowColor(Theme.COLORS[CalcAtkScreen.Colors.fill]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)
		-- Header text above canvas box
		local headerText = Utils.formatSpecialCharacters("Attacking Damage Calculator" or self.name)
		local headerShadow = Utils.calcShadowColor(Theme.COLORS["Main background"])
		Drawing.drawText(canvas.x, Constants.SCREEN.MARGIN - 2, Utils.toUpperUTF8(headerText), Theme.COLORS["Header text"], headerShadow)
		-- Draw the canvas box
		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)
		-- Draw all the buttons
		for _, button in pairs(CalcAtkScreen.Buttons or {}) do
			Drawing.drawButton(button, canvas.shadow)
		end
	end

	local createButtonInserts = function ()
		TrackerScreen.Buttons.LastAttackSummary.onClick = function(this)
			previousScreen = TrackerScreen
			if Battle.inBattle then
				autoApplyValues()
			end
			CalcAtkScreen.Buttons.CalculatedStatOutput:recalculate(true)
			CalcAtkScreen.refreshButtons()
			Program.changeScreenView(CalcAtkScreen)
		end
	end
	local removeButtonInserts = function()
		-- Restore the onclick functionality to default (as of 8.3.0, it's just empty, no action)
		TrackerScreen.Buttons.LastAttackSummary.onClick = function(this) end
	end

	-- EXTENSION FUNCTIONS
	-- Executed when the user clicks the "Check for Updates" button while viewing the extension details within the Tracker's UI
	function self.checkForUpdates()
		local versionCheckUrl = string.format("https://api.github.com/repos/%s/releases/latest", self.github)
		local versionResponsePattern = '"tag_name":%s+"%w+(%d+%.%d+)"' -- matches "1.0" in "tag_name": "v1.0"
		local downloadUrl = string.format("https://github.com/%s/releases/latest", self.github)
		local compareFunc = function(a, b) return a ~= b and not Utils.isNewerVersion(a, b) end -- if current version is *older* than online version
		local isUpdateAvailable = Utils.checkForVersionUpdate(versionCheckUrl, self.version, versionResponsePattern, compareFunc)
		return isUpdateAvailable, downloadUrl
	end

	-- Executed when the user clicks the "Options" button while viewing the extension details within the Tracker's UI
	function self.configureOptions()
		previousScreen = SingleExtensionScreen
		if Battle.inBattle then
			autoApplyValues()
		end
		CalcAtkScreen.Buttons.CalculatedStatOutput:recalculate(true)
		CalcAtkScreen.refreshButtons()
		Program.changeScreenView(CalcAtkScreen)
	end

	-- Executed only once: When the extension is enabled by the user, and/or when the Tracker first starts up, after it loads all other required files and code
	function self.startup()
		createButtonInserts()
		clearButtonValues()
		CalcAtkScreen.refreshButtons()
	end

	-- Executed only once: When the extension is disabled by the user, necessary to undo any customizations, if able
	function self.unload()
		removeButtonInserts()
	end

	-- Executed once every 30 frames, after most data from game memory is read in
	function self.afterProgramDataUpdate()
		if checkIfValuesChanged() then
			autoApplyValues()
		end
	end

	-- Executed after a battle ends, and only once per battle
	function self.afterBattleEnds()
		clearButtonValues()
		if Program.currentScreen == CalcAtkScreen then
			Program.changeScreenView(TrackerScreen)
		end
	end

	-- Executed once every 30 frames or after any redraw event is scheduled (i.e. most button presses)
	function self.afterRedraw()
		if Program.currentScreen ~= TrackerScreen or not Battle.inBattle then
			return
		end
		local lastDmgBtn = TrackerScreen.Buttons.LastAttackSummary
		if lastDmgBtn and lastDmgBtn:isVisible() then
			local color = Theme.COLORS[CalcAtkScreen.Colors.highlight]
			local shadowcolor = Utils.calcShadowColor(Theme.COLORS["Lower box background"])
			Drawing.drawImageAsPixels(Constants.PixelImages.NOTEPAD, Constants.SCREEN.WIDTH + 130, 140, color, shadowcolor)
		end
	end

	return self
end
return CalcAtk