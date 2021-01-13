-- physics
pixelToMeter = 32
love.physics.setMeter(pixelToMeter)
local world = love.physics.newWorld(0, 9.81*pixelToMeter, true)
local objects = {}

--gamemode
GameMode = {
   STACKING_TOWER = 0,
   PREPARATION = 1,
   FALLING = 2, 
   END_GAME = 3,
}
local gameMode = GameMode.STACKING_TOWER

-- fonts
local smallFont = love.graphics.newFont(10) --never used anyway lmao
local normalFont = love.graphics.newFont(15)
local scoreFont = love.graphics.newFont(30)
local bigFont = love.graphics.newFont(50)
local hugeFont = love.graphics.newFont(250)

--preparation
local countingDownNumberToSet = 3 --this is modificable
local countingDownNumber = countingDownNumberToSet

--score
local score = 100
local scoreValueOfPoint = 150

-- game parameters
local widthScreen, heightScreen = love.graphics.getDimensions()
local mover = 1
local moveSpeed = 4
local boxWidth = 200
local boxHeight = 100
local perfectPlacePercentage = 0.04
local boxCountToStartCamera = 2
local blinkActive = false;
local alphaIncrementator = 0.1;
local alphaLevel = 0.1
local chunkDropped = false;

--camera
local shiftedHeight = 0
local destinatedCameraHeight = -boxCountToStartCamera * boxHeight
local currentCameraHeight = 0
local cameraSpeed = 1.5
local fallingMultiplier = 5

--THE REAL PLAYER (not the fancy block that pretend that he is a player while he is not)
local theRealPlayerHorizontalSpeed = 8
local theRealPlayerVerticalSpeed = 2.5--3.5
local theRealPlayerX = love.graphics.getWidth()/2-50
local theRealPlayerY = 0

--klasa Box
Box = {width = 0, height = 0, xPos = 0, yPos = 0, rightOffsetX = 0, leftOffsetX = 0}

--point class
Point = {width = 0, height = 0, xPos = 0, yPos = 0}

--cooldown
local cooldownPress = 0
local cooldownValue = 25 --this might be changed

function cooldownResetUpdate()
  if(cooldownPress>0) then
	cooldownPress = cooldownPress - 1
  end
end

--collision
function checkCollision(x1,y1,w1,h1, x2,y2,w2,h2)
    return x1 < x2+w2 and
           x2 < x1+w1 and
           y1 < y2+h2 and
           y2 < y1+h1
  end

-- RESET
function reset()
    print("reset")
    score = 100
    playerHeigth = boxHeight
    playerWidth = boxWidth
    mover = 1
    moveSpeed = 4
    setPlayerBox()
    boxes = {}
    boxes = {box1}

    chunkDropped = false
    blinkActive = false
    cameraSpeed = 1.5
    objects = {}

    points = {}
    theRealPlayerX = love.graphics.getWidth()/2-50
    theRealPlayerY = 0
    gameMode = GameMode.STACKING_TOWER

    destinatedCameraHeight = -boxCountToStartCamera * boxHeight
    currentCameraHeight = 0
end
--

function Box:create (o)
    o.parent = self
    return o
end


local pointWidth = 64
local pointHeight = 64
function Point:create (o)
    o.parent = self
    return o
end

-- LOAD --------------------------------------
function love.load()
    -- images
    wallImg = love.graphics.newImage("brickwall.png")
    background = love.graphics.newImage("bg.png")
    wallBlinkMask = love.graphics.newImage("wall_test_blinMask.png")
    pointImg = love.graphics.newImage("player.png") --!!!
    playerImg = love.graphics.newImage("realPlayer.png")

    --audio
    pointAudio = love.audio.newSource("MouseClick.mp3", "static")
    blockAudio = love.audio.newSource("MouseClick.mp3", "static")

	playerWidth = 200
	playerHeigth = 100

	-- pierwszy blok
	box1 = Box:create{width = boxWidth, height = boxHeight, xPos = widthScreen/2 - boxWidth/2, yPos = heightScreen-(boxHeight * 1), rightOffsetX = 0, leftOffsetX = 0}
    boxes = {box1}
    points = {}
    player = {}
    setPlayerBox()
end

-- Camera related
function shiftCameraByBoxSize()
  destinatedCameraHeight = destinatedCameraHeight + boxHeight
end

function updateDrawCamera()
    --camera goes up in stacking tower
    if(gameMode == GameMode.STACKING_TOWER) then 
        if(#boxes> boxCountToStartCamera and destinatedCameraHeight>currentCameraHeight) then
  	        currentCameraHeight = currentCameraHeight + cameraSpeed
        end
    end

    --camera goes down in falling mode
    if(gameMode == GameMode.FALLING) then 
        if(currentCameraHeight>destinatedCameraHeight) then
        currentCameraHeight = currentCameraHeight - (cameraSpeed * fallingMultiplier)
        end
    end

    --no matter of the mode - camera have to be rendered at proper level
    love.graphics.translate(0, currentCameraHeight)
end

function setPlayerBox()
    local height = boxHeight
    for b in pairs(boxes) do
        height = height + boxes[b].height
    end
    player.x = widthScreen - boxWidth
    player.y = heightScreen - height
end

-- UPDATE --------------------------------------
function love.update(dt)
    print("updejt")
    -- update physics
    world:update(dt)

    --cooldown is used in different gamemodes so better always update it
    cooldownResetUpdate()

    --reset always available
    if love.keyboard.isDown("r") then
        reset()
    end

    if(gameMode==GameMode.STACKING_TOWER) then
        print("stacking")
        if player.x >= (widthScreen - boxWidth)  then
            mover = -1
        end

        if player.x <= 60 then
            mover = 1
        end

        player.x = player.x + mover*moveSpeed
		
        if (love.mouse.isDown("1") and cooldownPress==0) then
            newBox = Box:create{width = playerWidth, height = playerHeigth, xPos = player.x, yPos = player.y, rightOffsetX = 0, leftOffsetX = boxes[#boxes].leftOffsetX}
            
            if cutBlock() then 
                playBlockSound()
                table.insert(boxes, newBox)
                playerWidth = newBox.width
                playerHeigth = newBox.height
                setPlayerBox()
                score = #boxes*boxHeight
                shiftCameraByBoxSize()
                changeDifficultyLevel()
                cooldownPress=cooldownValue
            else
                if gameMode == GameMode.STACKING_TOWER then
                    GoToPreparationMode()
                end
            end
        end
    elseif(gameMode==GameMode.PREPARATION) then
        print("preparation")
        updatePositionOfRealPlayer()

        --counting goes down and cooldown is being reset
        if(cooldownPress==0) then
            cooldownPress = cooldownValue
            countingDownNumber = countingDownNumber - 1
        end

        --if the counting goes to 0 its time to change gamemode to falling
        if(countingDownNumber==0) then
            GoToFallingMode()
        end

    elseif(gameMode==GameMode.FALLING) then
        print("falling")
        checkCollisionsAndDeletePoints()
        updatePositionOfRealPlayer()

        if(love.keyboard.isDown("a") and theRealPlayerX>0) then
            theRealPlayerX = theRealPlayerX - theRealPlayerHorizontalSpeed
        end
        if(love.keyboard.isDown("d") and theRealPlayerX+playerImg:getWidth() < love.graphics.getWidth()) then
            theRealPlayerX = theRealPlayerX + theRealPlayerHorizontalSpeed
        end
            
    elseif(gameMode==GameMode.END_GAME) then
        print("end")
        --game ends here
    end
end

function playBlockSound()
    love.audio.stop()
    blockAudio:play()
end

function playPointSound()
    love.audio.stop()
    pointAudio:play()
end

function changeDifficultyLevel()
    if #boxes > 27 then
        moveSpeed = 9
        cameraSpeed = 3.5
    elseif #boxes > 17 then
        moveSpeed = 7
    elseif #boxes > 13 then
        moveSpeed = 6
        cameraSpeed = 3
    elseif #boxes > 7 then
        moveSpeed = 5
    end
end

function cutBlock()
    local offsetX = boxes[#boxes].xPos - player.x

    if (math.abs(offsetX) == boxes[#boxes].width) then
        return false
    end
	-- Nie trafił z lewej lub nie trafił z prawej
	if (player.x + playerWidth) < boxes[#boxes].xPos or player.x > boxes[#boxes].xPos + boxes[#boxes].width then
		return false
    else 
        if offsetX > 0 then
            -- perfect placement
            if offsetX <= boxWidth * perfectPlacePercentage then
                newBox.xPos = boxes[#boxes].xPos
                newBox.width = boxes[#boxes].width
                PerfetctPlaceBlink()
            else
                -- Wystaje z lewej
                newBox.xPos = player.x + offsetX
                newBox.width = newBox.width - offsetX
                newBox.leftOffsetX = newBox.leftOffsetX + offsetX

                -- x, y, szerokość, wysokość, spireStart, spriteEnd, direction
                CreateDropPart(player.x, newBox.yPos, offsetX, newBox.height, newBox.leftOffsetX-offsetX, offsetX, -1)
                PushDroppedChunk()
            end

		-- Wystaje z prawej
        elseif offsetX < 0 then
            -- perfect placement
            if offsetX*-1 <= boxWidth * perfectPlacePercentage then
                newBox.xPos = boxes[#boxes].xPos
                newBox.width = boxes[#boxes].width
                
                PerfetctPlaceBlink()
            else
                -- wystaje z prawej
                newBox.xPos = player.x
                newBox.width = newBox.width + offsetX
                newBox.rightOffsetX = newBox.rightOffsetX + (-offsetX)

                -- x, y, szerokość, wysokość, spireStart, spriteEnd, direction
                CreateDropPart(newBox.xPos + newBox.width, newBox.yPos, -offsetX, newBox.height, newBox.leftOffsetX + newBox.width, -offsetX, 1)
                PushDroppedChunk()
                
            end

        else
            newBox.xPos = boxes[#boxes].xPos
            newBox.width = boxes[#boxes].width
            PerfetctPlaceBlink()
		end

		return true
	end

end

function drawBoxes()
    i = 1
    for b in pairs(boxes) do
    	box = boxes[b]
        wallQuadBefore = love.graphics.newQuad(box.leftOffsetX, 0, box.width, box.height, wallImg:getWidth(), wallImg:getHeight())
        love.graphics.draw(wallImg, wallQuadBefore, box.xPos, box.yPos)

        i = i + 1
    end

end

function drawPoints()
    i = 1
    for b in pairs(points) do
        point = points[b]
        --print("draw point" .. b .. " at pos " .. point.xPos .. ", " .. point.yPos)

        --love.graphics.rectangle("line", box.xPos, box.yPos, box.width, box.height)


        -- pointQuadBefore = love.graphics.newQuad(0, 0, point.width, point.height, pointImg:getWidth(), pointImg:getHeight()) --duno why but pointImg nie dziala prawidlowo
        -- love.graphics.draw(pointImg, pointQuadBefore, point.xPos, point.yPos)
        love.graphics.draw(pointImg, point.xPos, point.yPos)
        i = i + 1
    end

end

function drawHelpers()
    base = love.graphics.getHeight() 
    local offset = 10
    local leftMargin = 10
    local maxHeight = -#boxes*(boxHeight*offset)

    love.graphics.line(leftMargin,base,leftMargin,maxHeight)--x1, y1, x2, y2

    for i=base,maxHeight,-100 do
        love.graphics.line(leftMargin,i,leftMargin+10,i)
        love.graphics.print(-i+heightScreen,leftMargin+10,i)
    end
end

function drawScore()
    love.graphics.setFont(scoreFont)
    love.graphics.print("Score: " .. score, widthScreen-200, 0-currentCameraHeight+30)
    love.graphics.setFont(normalFont)
end

-- DRAW --------------------------------------
function love.draw()

    --always outside the if????
    updateDrawCamera()

    --I dont actually know what the line under does but whatever
    love.graphics.translate(0, shiftedHeight)
    
    --print("camera height: " .. destinatedCameraHeight .. " " .. currentCameraHeight)

    --now it draws lose screen if you lose and game screen if you are still playing
    if(gameMode==GameMode.STACKING_TOWER) then
        drawBackground()
    

        -- player template
        -- tworzy obszar od 0,0 (lewy górny) do playerWidth playerHeigth (prawy dolny) (pokrywa cały obraz)
        -- i przesuwający takim obszarem w nim rysuje ile się da textury 
        wallQuad = love.graphics.newQuad(boxes[#boxes].leftOffsetX, 0, playerWidth, playerHeigth, wallImg:getWidth(), wallImg:getHeight())
        love.graphics.draw(wallImg, wallQuad, player.x, player.y)


        drawBoxes()
        -- Jak perfect place był to nakładaj maske z zaznaczeniem 
        if (blinkActive) then
            -- obszar gdzie nałożone będą na grafike transformacje
            love.graphics.push()

            -- stopniopowo pokazuj zaznazcenie (mignięcie)
            love.graphics.setColor(1, 1, 1, alphaLevel)
            alphaLevel = alphaLevel + alphaIncrementator
            -- doskaluj do zaznaczenie do uciętego boxa
            love.graphics.scale(boxes[#boxes].width/boxWidth, 1)
            love.graphics.draw(wallBlinkMask, boxes[#boxes].xPos/(boxes[#boxes].width/boxWidth), boxes[#boxes].yPos)

            if (alphaLevel >= 1) then
                alphaIncrementator = - alphaIncrementator
            end

            if (alphaLevel <= 0) then
                blinkActive = false
                alphaIncrementator = - alphaIncrementator
                alphaLevel = 0
            end
            -- wyjście z obszaru
            love.graphics.pop()
            love.graphics.setColor(1, 1, 1, 1)
        end

        RenderDropPart()
        -- koordynaty
        drawHelpers()
        drawScore()
    elseif(gameMode==GameMode.PREPARATION) then
        drawBackground()
        drawBoxes()
        drawScore()
        drawRealPlayer()
        drawCounter()
    elseif(gameMode==GameMode.FALLING) then
        drawBackground()
        drawBoxes()
        drawPoints()
        drawScore()
        drawRealPlayer()
    elseif(gameMode==GameMode.END_GAME) then
        drawLose()
    end
end

function drawCounter()
    love.graphics.setFont(hugeFont)
    love.graphics.print(countingDownNumber, love.graphics.getWidth()/2 - 50, 0 - currentCameraHeight)
end

function drawBackground()
    love.graphics.draw(background, 0, 0 - background:getHeight()+heightScreen)
end

function drawRealPlayer()
    love.graphics.draw(playerImg, theRealPlayerX, theRealPlayerY) -- 0 - currentCameraHeight
end

function updatePositionOfRealPlayer()
    if (currentCameraHeight > destinatedCameraHeight or gameMode==GameMode.PREPARATION) then
        theRealPlayerY = 0 - currentCameraHeight
    else
        theRealPlayerY = theRealPlayerY + (cameraSpeed * fallingMultiplier)
    end
    print(theRealPlayerY)
    if(theRealPlayerY>800) then
        GoToEndgameMode()
    end

end

function checkCollisionsAndDeletePoints()
    for p in pairs(points) do
        if(checkCollision(theRealPlayerX, theRealPlayerY, 
        playerImg:getWidth(), playerImg:getHeight(), 
        points[p].xPos, points[p].yPos, 
        pointImg:getWidth(), pointImg:getHeight())) then
            playPointSound()   
            score = score + scoreValueOfPoint
            table.remove(points, p)
        end
    end
end

function drawLose()
    w = love.graphics.getWidth()
    h = love.graphics.getWidth()
    
    love.graphics.setFont(bigFont)
    love.graphics.print("GAME OVER", w/2-150, h/2-200)
    love.graphics.setFont(normalFont)
    love.graphics.print("Your score: " .. score, w/2 - 60, h/2-130)
    
    love.graphics.print("Press R to reset", w/2 - 60, h/2-110)
    
end


function PreparePoints()
    print("Preparing points...")
    local i = 0
    for b in pairs(boxes) do
        if(i%3==0) then
            box = boxes[b]
            local randomWidth = math.random (0, love.graphics.getWidth())
            print(randomWidth)
            newPoint = Point:create{width = pointImg:getWidth(), height = pointImg:getHeight(), xPos = randomWidth, yPos = box.yPos}
            table.insert(points, newPoint)
            print("Point " .. b .. " added")
        end
        i = i + 1
    end
end

function PerfetctPlaceBlink()
    blinkActive = true;
end

function RenderDropPart()
    if (chunkDropped) then
        k = 1
        for d in pairs(objects) do
            drop = objects[d]
            dropQuad = love.graphics.newQuad(drop.startJpg, 0, drop.endJpg, drop.h, wallImg:getWidth(), wallImg:getHeight())
            love.graphics.draw(wallImg, dropQuad, drop.body:getX(), drop.body:getY())
            k = k + 1
        end
    end
end

function CreateDropPart(x, y, w, h, startSprite, endSprite, forceDirection)
    newDrop = {} 
    newDrop.x = x
    newDrop.y = y
    newDrop.w = w
    newDrop.h = h
    newDrop.startJpg = startSprite
    newDrop.endJpg = endSprite
    newDrop.direction = forceDirection

    newDrop.body = love.physics.newBody(world, newDrop.x, newDrop.y, "dynamic")
    newDrop.shape = love.physics.newRectangleShape(newDrop.w, newDrop.h)
    newDrop.fixture = love.physics.newFixture(newDrop.body, newDrop.shape, 1)
    newDrop.fixture:setRestitution(.9)
    table.insert(objects, newDrop)
    chunkDropped = true
    -- new object created
end

function PushDroppedChunk()
    objects[#objects].body:applyLinearImpulse(objects[#objects].direction * 130, -90) 
end


--mode-changing functions
function GoToPreparationMode()
    updatePositionOfRealPlayer()

    cooldownPress = 30
    countingDownNumber = countingDownNumberToSet

    gameMode = GameMode.PREPARATION
end

function GoToFallingMode()
    destinatedCameraHeight = 0

    --camera speed is set to the realPlayer's speed which is ugly solution but reliable (until one day...)
    cameraSpeed = theRealPlayerVerticalSpeed
    PreparePoints()
    gameMode = GameMode.FALLING
end

function GoToEndgameMode()
    gameMode = GameMode.END_GAME
end